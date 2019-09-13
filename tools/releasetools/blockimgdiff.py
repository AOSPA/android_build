# Copyright (C) 2014 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

from __future__ import print_function

import array
import copy
import functools
import heapq
import itertools
import logging
import multiprocessing
import os
import os.path
import re
import sys
import threading
import zlib
from collections import deque, namedtuple, OrderedDict
from hashlib import sha1

import common
from rangelib import RangeSet

__all__ = ["EmptyImage", "DataImage", "BlockImageDiff"]

logger = logging.getLogger(__name__)

# The tuple contains the style and bytes of a bsdiff|imgdiff patch.
PatchInfo = namedtuple("PatchInfo", ["imgdiff", "content"])


def compute_patch(srcfile, tgtfile, imgdiff=False):
  """Calls bsdiff|imgdiff to compute the patch data, returns a PatchInfo."""
  patchfile = common.MakeTempFile(prefix='patch-')

  cmd = ['imgdiff', '-z'] if imgdiff else ['bsdiff']
  cmd.extend([srcfile, tgtfile, patchfile])

  # Don't dump the bsdiff/imgdiff commands, which are not useful for the case
  # here, since they contain temp filenames only.
  proc = common.Run(cmd, verbose=False)
  output, _ = proc.communicate()

  if proc.returncode != 0:
    raise ValueError(output)

  with open(patchfile, 'rb') as f:
    return PatchInfo(imgdiff, f.read())


class Image(object):
  def RangeSha1(self, ranges):
    raise NotImplementedError

  def ReadRangeSet(self, ranges):
    raise NotImplementedError

  def TotalSha1(self, include_clobbered_blocks=False):
    raise NotImplementedError

  def WriteRangeDataToFd(self, ranges, fd):
    raise NotImplementedError


class EmptyImage(Image):
  """A zero-length image."""

  def __init__(self):
    self.blocksize = 4096
    self.care_map = RangeSet()
    self.clobbered_blocks = RangeSet()
    self.extended = RangeSet()
    self.total_blocks = 0
    self.file_map = {}
    self.hashtree_info = None

  def RangeSha1(self, ranges):
    return sha1().hexdigest()

  def ReadRangeSet(self, ranges):
    return ()

  def TotalSha1(self, include_clobbered_blocks=False):
    # EmptyImage always carries empty clobbered_blocks, so
    # include_clobbered_blocks can be ignored.
    assert self.clobbered_blocks.size() == 0
    return sha1().hexdigest()

  def WriteRangeDataToFd(self, ranges, fd):
    raise ValueError("Can't write data from EmptyImage to file")


class DataImage(Image):
  """An image wrapped around a single string of data."""

  def __init__(self, data, trim=False, pad=False):
    self.data = data
    self.blocksize = 4096

    assert not (trim and pad)

    partial = len(self.data) % self.blocksize
    padded = False
    if partial > 0:
      if trim:
        self.data = self.data[:-partial]
      elif pad:
        self.data += '\0' * (self.blocksize - partial)
        padded = True
      else:
        raise ValueError(("data for DataImage must be multiple of %d bytes "
                          "unless trim or pad is specified") %
                         (self.blocksize,))

    assert len(self.data) % self.blocksize == 0

    self.total_blocks = len(self.data) // self.blocksize
    self.care_map = RangeSet(data=(0, self.total_blocks))
    # When the last block is padded, we always write the whole block even for
    # incremental OTAs. Because otherwise the last block may get skipped if
    # unchanged for an incremental, but would fail the post-install
    # verification if it has non-zero contents in the padding bytes.
    # Bug: 23828506
    if padded:
      clobbered_blocks = [self.total_blocks-1, self.total_blocks]
    else:
      clobbered_blocks = []
    self.clobbered_blocks = clobbered_blocks
    self.extended = RangeSet()

    zero_blocks = []
    nonzero_blocks = []
    reference = '\0' * self.blocksize

    for i in range(self.total_blocks-1 if padded else self.total_blocks):
      d = self.data[i*self.blocksize : (i+1)*self.blocksize]
      if d == reference:
        zero_blocks.append(i)
        zero_blocks.append(i+1)
      else:
        nonzero_blocks.append(i)
        nonzero_blocks.append(i+1)

    assert zero_blocks or nonzero_blocks or clobbered_blocks

    self.file_map = dict()
    if zero_blocks:
      self.file_map["__ZERO"] = RangeSet(data=zero_blocks)
    if nonzero_blocks:
      self.file_map["__NONZERO"] = RangeSet(data=nonzero_blocks)
    if clobbered_blocks:
      self.file_map["__COPY"] = RangeSet(data=clobbered_blocks)

  def _GetRangeData(self, ranges):
    for s, e in ranges:
      yield self.data[s*self.blocksize:e*self.blocksize]

  def RangeSha1(self, ranges):
    h = sha1()
    for data in self._GetRangeData(ranges): # pylint: disable=not-an-iterable
      h.update(data)
    return h.hexdigest()

  def ReadRangeSet(self, ranges):
    return list(self._GetRangeData(ranges))

  def TotalSha1(self, include_clobbered_blocks=False):
    if not include_clobbered_blocks:
      return self.RangeSha1(self.care_map.subtract(self.clobbered_blocks))
    return sha1(self.data).hexdigest()

  def WriteRangeDataToFd(self, ranges, fd):
    for data in self._GetRangeData(ranges): # pylint: disable=not-an-iterable
      fd.write(data)


class FileImage(Image):
  """An image wrapped around a raw image file."""

  def __init__(self, path, hashtree_info_generator=None):
    self.path = path
    self.blocksize = 4096
    self._file_size = os.path.getsize(self.path)
    self._file = open(self.path, 'rb')

    if self._file_size % self.blocksize != 0:
      raise ValueError("Size of file %s must be multiple of %d bytes, but is %d"
                       % self.path, self.blocksize, self._file_size)

    self.total_blocks = self._file_size // self.blocksize
    self.care_map = RangeSet(data=(0, self.total_blocks))
    self.clobbered_blocks = RangeSet()
    self.extended = RangeSet()

    self.generator_lock = threading.Lock()

    self.hashtree_info = None
    if hashtree_info_generator:
      self.hashtree_info = hashtree_info_generator.Generate(self)

    zero_blocks = []
    nonzero_blocks = []
    reference = '\0' * self.blocksize

    for i in range(self.total_blocks):
      d = self._file.read(self.blocksize)
      if d == reference:
        zero_blocks.append(i)
        zero_blocks.append(i+1)
      else:
        nonzero_blocks.append(i)
        nonzero_blocks.append(i+1)

    assert zero_blocks or nonzero_blocks

    self.file_map = {}
    if zero_blocks:
      self.file_map["__ZERO"] = RangeSet(data=zero_blocks)
    if nonzero_blocks:
      self.file_map["__NONZERO"] = RangeSet(data=nonzero_blocks)
    if self.hashtree_info:
      self.file_map["__HASHTREE"] = self.hashtree_info.hashtree_range

  def __del__(self):
    self._file.close()

  def _GetRangeData(self, ranges):
    # Use a lock to protect the generator so that we will not run two
    # instances of this generator on the same object simultaneously.
    with self.generator_lock:
      for s, e in ranges:
        self._file.seek(s * self.blocksize)
        for _ in range(s, e):
          yield self._file.read(self.blocksize)

  def RangeSha1(self, ranges):
    h = sha1()
    for data in self._GetRangeData(ranges): # pylint: disable=not-an-iterable
      h.update(data)
    return h.hexdigest()

  def ReadRangeSet(self, ranges):
    return list(self._GetRangeData(ranges))

  def TotalSha1(self, include_clobbered_blocks=False):
    assert not self.clobbered_blocks
    return self.RangeSha1(self.care_map)

  def WriteRangeDataToFd(self, ranges, fd):
    for data in self._GetRangeData(ranges): # pylint: disable=not-an-iterable
      fd.write(data)


class Transfer(object):
  def __init__(self, tgt_name, src_name, tgt_ranges, src_ranges, tgt_sha1,
               src_sha1, style, by_id):
    self.tgt_name = tgt_name
    self.src_name = src_name
    self.tgt_ranges = tgt_ranges
    self.src_ranges = src_ranges
    self.tgt_sha1 = tgt_sha1
    self.src_sha1 = src_sha1
    self.style = style

    # We use OrderedDict rather than dict so that the output is repeatable;
    # otherwise it would depend on the hash values of the Transfer objects.
    self.goes_before = OrderedDict()
    self.goes_after = OrderedDict()

    self.stash_before = []
    self.use_stash = []

    self.id = len(by_id)
    by_id.append(self)

    self._patch_info = None

  @property
  def patch_info(self):
    return self._patch_info

  @patch_info.setter
  def patch_info(self, info):
    if info:
      assert self.style == "diff"
    self._patch_info = info

  def NetStashChange(self):
    return (sum(sr.size() for (_, sr) in self.stash_before) -
            sum(sr.size() for (_, sr) in self.use_stash))

  def ConvertToNew(self):
    assert self.style != "new"
    self.use_stash = []
    self.style = "new"
    self.src_ranges = RangeSet()
    self.patch_info = None

  def __str__(self):
    return (str(self.id) + ": <" + str(self.src_ranges) + " " + self.style +
            " to " + str(self.tgt_ranges) + ">")


@functools.total_ordering
class HeapItem(object):
  def __init__(self, item):
    self.item = item
    # Negate the score since python's heap is a min-heap and we want the
    # maximum score.
    self.score = -item.score

  def clear(self):
    self.item = None

  def __bool__(self):
    return self.item is not None

  # Python 2 uses __nonzero__, while Python 3 uses __bool__.
  __nonzero__ = __bool__

  # The rest operations are generated by functools.total_ordering decorator.
  def __eq__(self, other):
    return self.score == other.score

  def __le__(self, other):
    return self.score <= other.score


class ImgdiffStats(object):
  """A class that collects imgdiff stats.

  It keeps track of the files that will be applied imgdiff while generating
  BlockImageDiff. It also logs the ones that cannot use imgdiff, with specific
  reasons. The stats is only meaningful when imgdiff not being disabled by the
  caller of BlockImageDiff. In addition, only files with supported types
  (BlockImageDiff.FileTypeSupportedByImgdiff()) are allowed to be logged.
  """

  USED_IMGDIFF = "APK files diff'd with imgdiff"
  USED_IMGDIFF_LARGE_APK = "Large APK files split and diff'd with imgdiff"

  # Reasons for not applying imgdiff on APKs.
  SKIPPED_NONMONOTONIC = "Not used imgdiff due to having non-monotonic ranges"
  SKIPPED_SHARED_BLOCKS = "Not used imgdiff due to using shared blocks"
  SKIPPED_INCOMPLETE = "Not used imgdiff due to incomplete RangeSet"

  # The list of valid reasons, which will also be the dumped order in a report.
  REASONS = (
      USED_IMGDIFF,
      USED_IMGDIFF_LARGE_APK,
      SKIPPED_NONMONOTONIC,
      SKIPPED_SHARED_BLOCKS,
      SKIPPED_INCOMPLETE,
  )

  def  __init__(self):
    self.stats = {}

  def Log(self, filename, reason):
    """Logs why imgdiff can or cannot be applied to the given filename.

    Args:
      filename: The filename string.
      reason: One of the reason constants listed in REASONS.

    Raises:
      AssertionError: On unsupported filetypes or invalid reason.
    """
    assert BlockImageDiff.FileTypeSupportedByImgdiff(filename)
    assert reason in self.REASONS

    if reason not in self.stats:
      self.stats[reason] = set()
    self.stats[reason].add(filename)

  def Report(self):
    """Prints a report of the collected imgdiff stats."""

    def print_header(header, separator):
      logger.info(header)
      logger.info('%s\n', separator * len(header))

    print_header('  Imgdiff Stats Report  ', '=')
    for key in self.REASONS:
      if key not in self.stats:
        continue
      values = self.stats[key]
      section_header = ' {} (count: {}) '.format(key, len(values))
      print_header(section_header, '-')
      logger.info(''.join(['  {}\n'.format(name) for name in values]))


class BlockImageDiff(object):
  """Generates the diff of two block image objects.

  BlockImageDiff works on two image objects. An image object is anything that
  provides the following attributes:

     blocksize: the size in bytes of a block, currently must be 4096.

     total_blocks: the total size of the partition/image, in blocks.

     care_map: a RangeSet containing which blocks (in the range [0,
       total_blocks) we actually care about; i.e. which blocks contain data.

     file_map: a dict that partitions the blocks contained in care_map into
         smaller domains that are useful for doing diffs on. (Typically a domain
         is a file, and the key in file_map is the pathname.)

     clobbered_blocks: a RangeSet containing which blocks contain data but may
         be altered by the FS. They need to be excluded when verifying the
         partition integrity.

     ReadRangeSet(): a function that takes a RangeSet and returns the data
         contained in the image blocks of that RangeSet. The data is returned as
         a list or tuple of strings; concatenating the elements together should
         produce the requested data. Implementations are free to break up the
         data into list/tuple elements in any way that is convenient.

     RangeSha1(): a function that returns (as a hex string) the SHA-1 hash of
         all the data in the specified range.

     TotalSha1(): a function that returns (as a hex string) the SHA-1 hash of
         all the data in the image (ie, all the blocks in the care_map minus
         clobbered_blocks, or including the clobbered blocks if
         include_clobbered_blocks is True).

  When creating a BlockImageDiff, the src image may be None, in which case the
  list of transfers produced will never read from the original image.
  """

  def __init__(self, tgt, src=None, threads=None, version=4,
               disable_imgdiff=False):
    if threads is None:
      threads = multiprocessing.cpu_count() // 2
      if threads == 0:
        threads = 1
    self.threads = threads
    self.version = version
    self.transfers = []
    self.src_basenames = {}
    self.src_numpatterns = {}
    self._max_stashed_size = 0
    self.touched_src_ranges = RangeSet()
    self.touched_src_sha1 = None
    self.disable_imgdiff = disable_imgdiff
    self.imgdiff_stats = ImgdiffStats() if not disable_imgdiff else None

    assert version in (3, 4)

    self.tgt = tgt
    if src is None:
      src = EmptyImage()
    self.src = src

    # The updater code that installs the patch always uses 4k blocks.
    assert tgt.blocksize == 4096
    assert src.blocksize == 4096

    # The range sets in each filemap should comprise a partition of
    # the care map.
    self.AssertPartition(src.care_map, src.file_map.values())
    self.AssertPartition(tgt.care_map, tgt.file_map.values())

  @property
  def max_stashed_size(self):
    return self._max_stashed_size

  @staticmethod
  def FileTypeSupportedByImgdiff(filename):
    """Returns whether the file type is supported by imgdiff."""
    return filename.lower().endswith(('.apk', '.jar', '.zip'))

  def CanUseImgdiff(self, name, tgt_ranges, src_ranges, large_apk=False):
    """Checks whether we can apply imgdiff for the given RangeSets.

    For files in ZIP format (e.g., APKs, JARs, etc.) we would like to use
    'imgdiff -z' if possible. Because it usually produces significantly smaller
    patches than bsdiff.

    This is permissible if all of the following conditions hold.
      - The imgdiff hasn't been disabled by the caller (e.g. squashfs);
      - The file type is supported by imgdiff;
      - The source and target blocks are monotonic (i.e. the data is stored with
        blocks in increasing order);
      - Both files don't contain shared blocks;
      - Both files have complete lists of blocks;
      - We haven't removed any blocks from the source set.

    If all these conditions are satisfied, concatenating all the blocks in the
    RangeSet in order will produce a valid ZIP file (plus possibly extra zeros
    in the last block). imgdiff is fine with extra zeros at the end of the file.

    Args:
      name: The filename to be diff'd.
      tgt_ranges: The target RangeSet.
      src_ranges: The source RangeSet.
      large_apk: Whether this is to split a large APK.

    Returns:
      A boolean result.
    """
    if self.disable_imgdiff or not self.FileTypeSupportedByImgdiff(name):
      return False

    if not tgt_ranges.monotonic or not src_ranges.monotonic:
      self.imgdiff_stats.Log(name, ImgdiffStats.SKIPPED_NONMONOTONIC)
      return False

    if (tgt_ranges.extra.get('uses_shared_blocks') or
        src_ranges.extra.get('uses_shared_blocks')):
      self.imgdiff_stats.Log(name, ImgdiffStats.SKIPPED_SHARED_BLOCKS)
      return False

    if tgt_ranges.extra.get('incomplete') or src_ranges.extra.get('incomplete'):
      self.imgdiff_stats.Log(name, ImgdiffStats.SKIPPED_INCOMPLETE)
      return False

    reason = (ImgdiffStats.USED_IMGDIFF_LARGE_APK if large_apk
              else ImgdiffStats.USED_IMGDIFF)
    self.imgdiff_stats.Log(name, reason)
    return True

  def Compute(self, prefix):
    # When looking for a source file to use as the diff input for a
    # target file, we try:
    #   1) an exact path match if available, otherwise
    #   2) a exact basename match if available, otherwise
    #   3) a basename match after all runs of digits are replaced by
    #      "#" if available, otherwise
    #   4) we have no source for this target.
    self.AbbreviateSourceNames()
    self.FindTransfers()

    self.FindSequenceForTransfers()

    # Ensure the runtime stash size is under the limit.
    if common.OPTIONS.cache_size is not None:
      stash_limit = (common.OPTIONS.cache_size *
                     common.OPTIONS.stash_threshold / self.tgt.blocksize)
      # Ignore the stash limit and calculate the maximum simultaneously stashed
      # blocks needed.
      _, max_stashed_blocks = self.ReviseStashSize(ignore_stash_limit=True)

      # We cannot stash more blocks than the stash limit simultaneously. As a
      # result, some 'diff' commands will be converted to new; leading to an
      # unintended large package. To mitigate this issue, we can carefully
      # choose the transfers for conversion. The number '1024' can be further
      # tweaked here to balance the package size and build time.
      if max_stashed_blocks > stash_limit + 1024:
        self.SelectAndConvertDiffTransfersToNew(
            max_stashed_blocks - stash_limit)
        # Regenerate the sequence as the graph has changed.
        self.FindSequenceForTransfers()

      # Revise the stash size again to keep the size under limit.
      self.ReviseStashSize()

    # Double-check our work.
    self.AssertSequenceGood()
    self.AssertSha1Good()

    self.ComputePatches(prefix)
    self.WriteTransfers(prefix)

    # Report the imgdiff stats.
    if not self.disable_imgdiff:
      self.imgdiff_stats.Report()

  def WriteTransfers(self, prefix):
    def WriteSplitTransfers(out, style, target_blocks):
      """Limit the size of operand in command 'new' and 'zero' to 1024 blocks.

      This prevents the target size of one command from being too large; and
      might help to avoid fsync errors on some devices."""

      assert style == "new" or style == "zero"
      blocks_limit = 1024
      total = 0
      while target_blocks:
        blocks_to_write = target_blocks.first(blocks_limit)
        out.append("%s %s\n" % (style, blocks_to_write.to_string_raw()))
        total += blocks_to_write.size()
        target_blocks = target_blocks.subtract(blocks_to_write)
      return total

    out = []
    total = 0

    # In BBOTA v3+, it uses the hash of the stashed blocks as the stash slot
    # id. 'stashes' records the map from 'hash' to the ref count. The stash
    # will be freed only if the count decrements to zero.
    stashes = {}
    stashed_blocks = 0
    max_stashed_blocks = 0

    for xf in self.transfers:

      for _, sr in xf.stash_before:
        sh = self.src.RangeSha1(sr)
        if sh in stashes:
          stashes[sh] += 1
        else:
          stashes[sh] = 1
          stashed_blocks += sr.size()
          self.touched_src_ranges = self.touched_src_ranges.union(sr)
          out.append("stash %s %s\n" % (sh, sr.to_string_raw()))

      if stashed_blocks > max_stashed_blocks:
        max_stashed_blocks = stashed_blocks

      free_string = []
      free_size = 0

      #   <# blocks> <src ranges>
      #     OR
      #   <# blocks> <src ranges> <src locs> <stash refs...>
      #     OR
      #   <# blocks> - <stash refs...>

      size = xf.src_ranges.size()
      src_str_buffer = [str(size)]

      unstashed_src_ranges = xf.src_ranges
      mapped_stashes = []
      for _, sr in xf.use_stash:
        unstashed_src_ranges = unstashed_src_ranges.subtract(sr)
        sh = self.src.RangeSha1(sr)
        sr = xf.src_ranges.map_within(sr)
        mapped_stashes.append(sr)
        assert sh in stashes
        src_str_buffer.append("%s:%s" % (sh, sr.to_string_raw()))
        stashes[sh] -= 1
        if stashes[sh] == 0:
          free_string.append("free %s\n" % (sh,))
          free_size += sr.size()
          stashes.pop(sh)

      if unstashed_src_ranges:
        src_str_buffer.insert(1, unstashed_src_ranges.to_string_raw())
        if xf.use_stash:
          mapped_unstashed = xf.src_ranges.map_within(unstashed_src_ranges)
          src_str_buffer.insert(2, mapped_unstashed.to_string_raw())
          mapped_stashes.append(mapped_unstashed)
          self.AssertPartition(RangeSet(data=(0, size)), mapped_stashes)
      else:
        src_str_buffer.insert(1, "-")
        self.AssertPartition(RangeSet(data=(0, size)), mapped_stashes)

      src_str = " ".join(src_str_buffer)

      # version 3+:
      #   zero <rangeset>
      #   new <rangeset>
      #   erase <rangeset>
      #   bsdiff patchstart patchlen srchash tgthash <tgt rangeset> <src_str>
      #   imgdiff patchstart patchlen srchash tgthash <tgt rangeset> <src_str>
      #   move hash <tgt rangeset> <src_str>

      tgt_size = xf.tgt_ranges.size()

      if xf.style == "new":
        assert xf.tgt_ranges
        assert tgt_size == WriteSplitTransfers(out, xf.style, xf.tgt_ranges)
        total += tgt_size
      elif xf.style == "move":
        assert xf.tgt_ranges
        assert xf.src_ranges.size() == tgt_size
        if xf.src_ranges != xf.tgt_ranges:
          # take into account automatic stashing of overlapping blocks
          if xf.src_ranges.overlaps(xf.tgt_ranges):
            temp_stash_usage = stashed_blocks + xf.src_ranges.size()
            if temp_stash_usage > max_stashed_blocks:
              max_stashed_blocks = temp_stash_usage

          self.touched_src_ranges = self.touched_src_ranges.union(
              xf.src_ranges)

          out.append("%s %s %s %s\n" % (
              xf.style,
              xf.tgt_sha1,
              xf.tgt_ranges.to_string_raw(), src_str))
          total += tgt_size
      elif xf.style in ("bsdiff", "imgdiff"):
        assert xf.tgt_ranges
        assert xf.src_ranges
        # take into account automatic stashing of overlapping blocks
        if xf.src_ranges.overlaps(xf.tgt_ranges):
          temp_stash_usage = stashed_blocks + xf.src_ranges.size()
          if temp_stash_usage > max_stashed_blocks:
            max_stashed_blocks = temp_stash_usage

        self.touched_src_ranges = self.touched_src_ranges.union(xf.src_ranges)

        out.append("%s %d %d %s %s %s %s\n" % (
            xf.style,
            xf.patch_start, xf.patch_len,
            xf.src_sha1,
            xf.tgt_sha1,
            xf.tgt_ranges.to_string_raw(), src_str))
        total += tgt_size
      elif xf.style == "zero":
        assert xf.tgt_ranges
        to_zero = xf.tgt_ranges.subtract(xf.src_ranges)
        assert WriteSplitTransfers(out, xf.style, to_zero) == to_zero.size()
        total += to_zero.size()
      else:
        raise ValueError("unknown transfer style '%s'\n" % xf.style)

      if free_string:
        out.append("".join(free_string))
        stashed_blocks -= free_size

      if common.OPTIONS.cache_size is not None:
        # Sanity check: abort if we're going to need more stash space than
        # the allowed size (cache_size * threshold). There are two purposes
        # of having a threshold here. a) Part of the cache may have been
        # occupied by some recovery logs. b) It will buy us some time to deal
        # with the oversize issue.
        cache_size = common.OPTIONS.cache_size
        stash_threshold = common.OPTIONS.stash_threshold
        max_allowed = cache_size * stash_threshold
        assert max_stashed_blocks * self.tgt.blocksize <= max_allowed, \
               'Stash size %d (%d * %d) exceeds the limit %d (%d * %.2f)' % (
                   max_stashed_blocks * self.tgt.blocksize, max_stashed_blocks,
                   self.tgt.blocksize, max_allowed, cache_size,
                   stash_threshold)

    self.touched_src_sha1 = self.src.RangeSha1(self.touched_src_ranges)

    if self.tgt.hashtree_info:
      out.append("compute_hash_tree {} {} {} {} {}\n".format(
          self.tgt.hashtree_info.hashtree_range.to_string_raw(),
          self.tgt.hashtree_info.filesystem_range.to_string_raw(),
          self.tgt.hashtree_info.hash_algorithm,
          self.tgt.hashtree_info.salt,
          self.tgt.hashtree_info.root_hash))

    # Zero out extended blocks as a workaround for bug 20881595.
    if self.tgt.extended:
      assert (WriteSplitTransfers(out, "zero", self.tgt.extended) ==
              self.tgt.extended.size())
      total += self.tgt.extended.size()

    # We erase all the blocks on the partition that a) don't contain useful
    # data in the new image; b) will not be touched by dm-verity. Out of those
    # blocks, we erase the ones that won't be used in this update at the
    # beginning of an update. The rest would be erased at the end. This is to
    # work around the eMMC issue observed on some devices, which may otherwise
    # get starving for clean blocks and thus fail the update. (b/28347095)
    all_tgt = RangeSet(data=(0, self.tgt.total_blocks))
    all_tgt_minus_extended = all_tgt.subtract(self.tgt.extended)
    new_dontcare = all_tgt_minus_extended.subtract(self.tgt.care_map)

    erase_first = new_dontcare.subtract(self.touched_src_ranges)
    if erase_first:
      out.insert(0, "erase %s\n" % (erase_first.to_string_raw(),))

    erase_last = new_dontcare.subtract(erase_first)
    if erase_last:
      out.append("erase %s\n" % (erase_last.to_string_raw(),))

    out.insert(0, "%d\n" % (self.version,))   # format version number
    out.insert(1, "%d\n" % (total,))
    # v3+: the number of stash slots is unused.
    out.insert(2, "0\n")
    out.insert(3, str(max_stashed_blocks) + "\n")

    with open(prefix + ".transfer.list", "w") as f:
      for i in out:
        f.write(i)

    self._max_stashed_size = max_stashed_blocks * self.tgt.blocksize
    OPTIONS = common.OPTIONS
    if OPTIONS.cache_size is not None:
      max_allowed = OPTIONS.cache_size * OPTIONS.stash_threshold
      logger.info(
          "max stashed blocks: %d  (%d bytes), limit: %d bytes (%.2f%%)\n",
          max_stashed_blocks, self._max_stashed_size, max_allowed,
          self._max_stashed_size * 100.0 / max_allowed)
    else:
      logger.info(
          "max stashed blocks: %d  (%d bytes), limit: <unknown>\n",
          max_stashed_blocks, self._max_stashed_size)

  def ReviseStashSize(self, ignore_stash_limit=False):
    """ Revises the transfers to keep the stash size within the size limit.

    Iterates through the transfer list and calculates the stash size each
    transfer generates. Converts the affected transfers to new if we reach the
    stash limit.

    Args:
      ignore_stash_limit: Ignores the stash limit and calculates the max
      simultaneous stashed blocks instead. No change will be made to the
      transfer list with this flag.

    Return:
      A tuple of (tgt blocks converted to new, max stashed blocks)
    """
    logger.info("Revising stash size...")
    stash_map = {}

    # Create the map between a stash and its def/use points. For example, for a
    # given stash of (raw_id, sr), stash_map[raw_id] = (sr, def_cmd, use_cmd).
    for xf in self.transfers:
      # Command xf defines (stores) all the stashes in stash_before.
      for stash_raw_id, sr in xf.stash_before:
        stash_map[stash_raw_id] = (sr, xf)

      # Record all the stashes command xf uses.
      for stash_raw_id, _ in xf.use_stash:
        stash_map[stash_raw_id] += (xf,)

    max_allowed_blocks = None
    if not ignore_stash_limit:
      # Compute the maximum blocks available for stash based on /cache size and
      # the threshold.
      cache_size = common.OPTIONS.cache_size
      stash_threshold = common.OPTIONS.stash_threshold
      max_allowed_blocks = cache_size * stash_threshold / self.tgt.blocksize

    # See the comments for 'stashes' in WriteTransfers().
    stashes = {}
    stashed_blocks = 0
    new_blocks = 0
    max_stashed_blocks = 0

    # Now go through all the commands. Compute the required stash size on the
    # fly. If a command requires excess stash than available, it deletes the
    # stash by replacing the command that uses the stash with a "new" command
    # instead.
    for xf in self.transfers:
      replaced_cmds = []

      # xf.stash_before generates explicit stash commands.
      for stash_raw_id, sr in xf.stash_before:
        # Check the post-command stashed_blocks.
        stashed_blocks_after = stashed_blocks
        sh = self.src.RangeSha1(sr)
        if sh not in stashes:
          stashed_blocks_after += sr.size()

        if max_allowed_blocks and stashed_blocks_after > max_allowed_blocks:
          # We cannot stash this one for a later command. Find out the command
          # that will use this stash and replace the command with "new".
          use_cmd = stash_map[stash_raw_id][2]
          replaced_cmds.append(use_cmd)
          logger.info("%10d  %9s  %s", sr.size(), "explicit", use_cmd)
        else:
          # Update the stashes map.
          if sh in stashes:
            stashes[sh] += 1
          else:
            stashes[sh] = 1
          stashed_blocks = stashed_blocks_after
          max_stashed_blocks = max(max_stashed_blocks, stashed_blocks)

      # "move" and "diff" may introduce implicit stashes in BBOTA v3. Prior to
      # ComputePatches(), they both have the style of "diff".
      if xf.style == "diff":
        assert xf.tgt_ranges and xf.src_ranges
        if xf.src_ranges.overlaps(xf.tgt_ranges):
          if (max_allowed_blocks and
              stashed_blocks + xf.src_ranges.size() > max_allowed_blocks):
            replaced_cmds.append(xf)
            logger.info("%10d  %9s  %s", xf.src_ranges.size(), "implicit", xf)
          else:
            # The whole source ranges will be stashed for implicit stashes.
            max_stashed_blocks = max(max_stashed_blocks,
                                     stashed_blocks + xf.src_ranges.size())

      # Replace the commands in replaced_cmds with "new"s.
      for cmd in replaced_cmds:
        # It no longer uses any commands in "use_stash". Remove the def points
        # for all those stashes.
        for stash_raw_id, sr in cmd.use_stash:
          def_cmd = stash_map[stash_raw_id][1]
          assert (stash_raw_id, sr) in def_cmd.stash_before
          def_cmd.stash_before.remove((stash_raw_id, sr))

        # Add up blocks that violates space limit and print total number to
        # screen later.
        new_blocks += cmd.tgt_ranges.size()
        cmd.ConvertToNew()

      # xf.use_stash may generate free commands.
      for _, sr in xf.use_stash:
        sh = self.src.RangeSha1(sr)
        assert sh in stashes
        stashes[sh] -= 1
        if stashes[sh] == 0:
          stashed_blocks -= sr.size()
          stashes.pop(sh)

    num_of_bytes = new_blocks * self.tgt.blocksize
    logger.info(
        "  Total %d blocks (%d bytes) are packed as new blocks due to "
        "insufficient cache size. Maximum blocks stashed simultaneously: %d",
        new_blocks, num_of_bytes, max_stashed_blocks)
    return new_blocks, max_stashed_blocks

  def ComputePatches(self, prefix):
    logger.info("Reticulating splines...")
    diff_queue = []
    patch_num = 0
    with open(prefix + ".new.dat", "wb") as new_f:
      for index, xf in enumerate(self.transfers):
        if xf.style == "zero":
          tgt_size = xf.tgt_ranges.size() * self.tgt.blocksize
          logger.info(
              "%10d %10d (%6.2f%%) %7s %s %s", tgt_size, tgt_size, 100.0,
              xf.style, xf.tgt_name, str(xf.tgt_ranges))

        elif xf.style == "new":
          self.tgt.WriteRangeDataToFd(xf.tgt_ranges, new_f)
          tgt_size = xf.tgt_ranges.size() * self.tgt.blocksize
          logger.info(
              "%10d %10d (%6.2f%%) %7s %s %s", tgt_size, tgt_size, 100.0,
              xf.style, xf.tgt_name, str(xf.tgt_ranges))

        elif xf.style == "diff":
          # We can't compare src and tgt directly because they may have
          # the same content but be broken up into blocks differently, eg:
          #
          #    ["he", "llo"]  vs  ["h", "ello"]
          #
          # We want those to compare equal, ideally without having to
          # actually concatenate the strings (these may be tens of
          # megabytes).
          if xf.src_sha1 == xf.tgt_sha1:
            # These are identical; we don't need to generate a patch,
            # just issue copy commands on the device.
            xf.style = "move"
            xf.patch_info = None
            tgt_size = xf.tgt_ranges.size() * self.tgt.blocksize
            if xf.src_ranges != xf.tgt_ranges:
              logger.info(
                  "%10d %10d (%6.2f%%) %7s %s %s (from %s)", tgt_size, tgt_size,
                  100.0, xf.style,
                  xf.tgt_name if xf.tgt_name == xf.src_name else (
                      xf.tgt_name + " (from " + xf.src_name + ")"),
                  str(xf.tgt_ranges), str(xf.src_ranges))
          else:
            if xf.patch_info:
              # We have already generated the patch (e.g. during split of large
              # APKs or reduction of stash size)
              imgdiff = xf.patch_info.imgdiff
            else:
              imgdiff = self.CanUseImgdiff(
                  xf.tgt_name, xf.tgt_ranges, xf.src_ranges)
            xf.style = "imgdiff" if imgdiff else "bsdiff"
            diff_queue.append((index, imgdiff, patch_num))
            patch_num += 1

        else:
          assert False, "unknown style " + xf.style

    patches = self.ComputePatchesForInputList(diff_queue, False)

    offset = 0
    with open(prefix + ".patch.dat", "wb") as patch_fd:
      for index, patch_info, _ in patches:
        xf = self.transfers[index]
        xf.patch_len = len(patch_info.content)
        xf.patch_start = offset
        offset += xf.patch_len
        patch_fd.write(patch_info.content)

        tgt_size = xf.tgt_ranges.size() * self.tgt.blocksize
        logger.info(
            "%10d %10d (%6.2f%%) %7s %s %s %s", xf.patch_len, tgt_size,
            xf.patch_len * 100.0 / tgt_size, xf.style,
            xf.tgt_name if xf.tgt_name == xf.src_name else (
                xf.tgt_name + " (from " + xf.src_name + ")"),
            xf.tgt_ranges, xf.src_ranges)

  def AssertSha1Good(self):
    """Check the SHA-1 of the src & tgt blocks in the transfer list.

    Double check the SHA-1 value to avoid the issue in b/71908713, where
    SparseImage.RangeSha1() messed up with the hash calculation in multi-thread
    environment. That specific problem has been fixed by protecting the
    underlying generator function 'SparseImage._GetRangeData()' with lock.
    """
    for xf in self.transfers:
      tgt_sha1 = self.tgt.RangeSha1(xf.tgt_ranges)
      assert xf.tgt_sha1 == tgt_sha1
      if xf.style == "diff":
        src_sha1 = self.src.RangeSha1(xf.src_ranges)
        assert xf.src_sha1 == src_sha1

  def AssertSequenceGood(self):
    # Simulate the sequences of transfers we will output, and check that:
    # - we never read a block after writing it, and
    # - we write every block we care about exactly once.

    # Start with no blocks having been touched yet.
    touched = array.array("B", b"\0" * self.tgt.total_blocks)

    # Imagine processing the transfers in order.
    for xf in self.transfers:
      # Check that the input blocks for this transfer haven't yet been touched.

      x = xf.src_ranges
      for _, sr in xf.use_stash:
        x = x.subtract(sr)

      for s, e in x:
        # Source image could be larger. Don't check the blocks that are in the
        # source image only. Since they are not in 'touched', and won't ever
        # be touched.
        for i in range(s, min(e, self.tgt.total_blocks)):
          assert touched[i] == 0

      # Check that the output blocks for this transfer haven't yet
      # been touched, and touch all the blocks written by this
      # transfer.
      for s, e in xf.tgt_ranges:
        for i in range(s, e):
          assert touched[i] == 0
          touched[i] = 1

    if self.tgt.hashtree_info:
      for s, e in self.tgt.hashtree_info.hashtree_range:
        for i in range(s, e):
          assert touched[i] == 0
          touched[i] = 1

    # Check that we've written every target block.
    for s, e in self.tgt.care_map:
      for i in range(s, e):
        assert touched[i] == 1

  def FindSequenceForTransfers(self):
    """Finds a sequence for the given transfers.

     The goal is to minimize the violation of order dependencies between these
     transfers, so that fewer blocks are stashed when applying the update.
    """

    # Clear the existing dependency between transfers
    for xf in self.transfers:
      xf.goes_before = OrderedDict()
      xf.goes_after = OrderedDict()

      xf.stash_before = []
      xf.use_stash = []

    # Find the ordering dependencies among transfers (this is O(n^2)
    # in the number of transfers).
    self.GenerateDigraph()
    # Find a sequence of transfers that satisfies as many ordering
    # dependencies as possible (heuristically).
    self.FindVertexSequence()
    # Fix up the ordering dependencies that the sequence didn't
    # satisfy.
    self.ReverseBackwardEdges()
    self.ImproveVertexSequence()

  def ImproveVertexSequence(self):
    logger.info("Improving vertex order...")

    # At this point our digraph is acyclic; we reversed any edges that
    # were backwards in the heuristically-generated sequence.  The
    # previously-generated order is still acceptable, but we hope to
    # find a better order that needs less memory for stashed data.
    # Now we do a topological sort to generate a new vertex order,
    # using a greedy algorithm to choose which vertex goes next
    # whenever we have a choice.

    # Make a copy of the edge set; this copy will get destroyed by the
    # algorithm.
    for xf in self.transfers:
      xf.incoming = xf.goes_after.copy()
      xf.outgoing = xf.goes_before.copy()

    L = []   # the new vertex order

    # S is the set of sources in the remaining graph; we always choose
    # the one that leaves the least amount of stashed data after it's
    # executed.
    S = [(u.NetStashChange(), u.order, u) for u in self.transfers
         if not u.incoming]
    heapq.heapify(S)

    while S:
      _, _, xf = heapq.heappop(S)
      L.append(xf)
      for u in xf.outgoing:
        del u.incoming[xf]
        if not u.incoming:
          heapq.heappush(S, (u.NetStashChange(), u.order, u))

    # if this fails then our graph had a cycle.
    assert len(L) == len(self.transfers)

    self.transfers = L
    for i, xf in enumerate(L):
      xf.order = i

  def ReverseBackwardEdges(self):
    """Reverse unsatisfying edges and compute pairs of stashed blocks.

    For each transfer, make sure it properly stashes the blocks it touches and
    will be used by later transfers. It uses pairs of (stash_raw_id, range) to
    record the blocks to be stashed. 'stash_raw_id' is an id that uniquely
    identifies each pair. Note that for the same range (e.g. RangeSet("1-5")),
    it is possible to have multiple pairs with different 'stash_raw_id's. Each
    'stash_raw_id' will be consumed by one transfer. In BBOTA v3+, identical
    blocks will be written to the same stash slot in WriteTransfers().
    """

    logger.info("Reversing backward edges...")
    in_order = 0
    out_of_order = 0
    stash_raw_id = 0
    stash_size = 0

    for xf in self.transfers:
      for u in xf.goes_before.copy():
        # xf should go before u
        if xf.order < u.order:
          # it does, hurray!
          in_order += 1
        else:
          # it doesn't, boo.  modify u to stash the blocks that it
          # writes that xf wants to read, and then require u to go
          # before xf.
          out_of_order += 1

          overlap = xf.src_ranges.intersect(u.tgt_ranges)
          assert overlap

          u.stash_before.append((stash_raw_id, overlap))
          xf.use_stash.append((stash_raw_id, overlap))
          stash_raw_id += 1
          stash_size += overlap.size()

          # reverse the edge direction; now xf must go after u
          del xf.goes_before[u]
          del u.goes_after[xf]
          xf.goes_after[u] = None    # value doesn't matter
          u.goes_before[xf] = None

    logger.info(
        "  %d/%d dependencies (%.2f%%) were violated; %d source blocks "
        "stashed.", out_of_order, in_order + out_of_order,
        (out_of_order * 100.0 / (in_order + out_of_order)) if (
            in_order + out_of_order) else 0.0,
        stash_size)

  def FindVertexSequence(self):
    logger.info("Finding vertex sequence...")

    # This is based on "A Fast & Effective Heuristic for the Feedback
    # Arc Set Problem" by P. Eades, X. Lin, and W.F. Smyth.  Think of
    # it as starting with the digraph G and moving all the vertices to
    # be on a horizontal line in some order, trying to minimize the
    # number of edges that end up pointing to the left.  Left-pointing
    # edges will get removed to turn the digraph into a DAG.  In this
    # case each edge has a weight which is the number of source blocks
    # we'll lose if that edge is removed; we try to minimize the total
    # weight rather than just the number of edges.

    # Make a copy of the edge set; this copy will get destroyed by the
    # algorithm.
    for xf in self.transfers:
      xf.incoming = xf.goes_after.copy()
      xf.outgoing = xf.goes_before.copy()
      xf.score = sum(xf.outgoing.values()) - sum(xf.incoming.values())

    # We use an OrderedDict instead of just a set so that the output
    # is repeatable; otherwise it would depend on the hash values of
    # the transfer objects.
    G = OrderedDict()
    for xf in self.transfers:
      G[xf] = None
    s1 = deque()  # the left side of the sequence, built from left to right
    s2 = deque()  # the right side of the sequence, built from right to left

    heap = []
    for xf in self.transfers:
      xf.heap_item = HeapItem(xf)
      heap.append(xf.heap_item)
    heapq.heapify(heap)

    # Use OrderedDict() instead of set() to preserve the insertion order. Need
    # to use 'sinks[key] = None' to add key into the set. sinks will look like
    # { key1: None, key2: None, ... }.
    sinks = OrderedDict.fromkeys(u for u in G if not u.outgoing)
    sources = OrderedDict.fromkeys(u for u in G if not u.incoming)

    def adjust_score(iu, delta):
      iu.score += delta
      iu.heap_item.clear()
      iu.heap_item = HeapItem(iu)
      heapq.heappush(heap, iu.heap_item)

    while G:
      # Put all sinks at the end of the sequence.
      while sinks:
        new_sinks = OrderedDict()
        for u in sinks:
          if u not in G:
            continue
          s2.appendleft(u)
          del G[u]
          for iu in u.incoming:
            adjust_score(iu, -iu.outgoing.pop(u))
            if not iu.outgoing:
              new_sinks[iu] = None
        sinks = new_sinks

      # Put all the sources at the beginning of the sequence.
      while sources:
        new_sources = OrderedDict()
        for u in sources:
          if u not in G:
            continue
          s1.append(u)
          del G[u]
          for iu in u.outgoing:
            adjust_score(iu, +iu.incoming.pop(u))
            if not iu.incoming:
              new_sources[iu] = None
        sources = new_sources

      if not G:
        break

      # Find the "best" vertex to put next.  "Best" is the one that
      # maximizes the net difference in source blocks saved we get by
      # pretending it's a source rather than a sink.

      while True:
        u = heapq.heappop(heap)
        if u and u.item in G:
          u = u.item
          break

      s1.append(u)
      del G[u]
      for iu in u.outgoing:
        adjust_score(iu, +iu.incoming.pop(u))
        if not iu.incoming:
          sources[iu] = None

      for iu in u.incoming:
        adjust_score(iu, -iu.outgoing.pop(u))
        if not iu.outgoing:
          sinks[iu] = None

    # Now record the sequence in the 'order' field of each transfer,
    # and by rearranging self.transfers to be in the chosen sequence.

    new_transfers = []
    for x in itertools.chain(s1, s2):
      x.order = len(new_transfers)
      new_transfers.append(x)
      del x.incoming
      del x.outgoing

    self.transfers = new_transfers

  def GenerateDigraph(self):
    logger.info("Generating digraph...")

    # Each item of source_ranges will be:
    #   - None, if that block is not used as a source,
    #   - an ordered set of transfers.
    source_ranges = []
    for b in self.transfers:
      for s, e in b.src_ranges:
        if e > len(source_ranges):
          source_ranges.extend([None] * (e-len(source_ranges)))
        for i in range(s, e):
          if source_ranges[i] is None:
            source_ranges[i] = OrderedDict.fromkeys([b])
          else:
            source_ranges[i][b] = None

    for a in self.transfers:
      intersections = OrderedDict()
      for s, e in a.tgt_ranges:
        for i in range(s, e):
          if i >= len(source_ranges):
            break
          # Add all the Transfers in source_ranges[i] to the (ordered) set.
          if source_ranges[i] is not None:
            for j in source_ranges[i]:
              intersections[j] = None

      for b in intersections:
        if a is b:
          continue

        # If the blocks written by A are read by B, then B needs to go before A.
        i = a.tgt_ranges.intersect(b.src_ranges)
        if i:
          if b.src_name == "__ZERO":
            # the cost of removing source blocks for the __ZERO domain
            # is (nearly) zero.
            size = 0
          else:
            size = i.size()
          b.goes_before[a] = size
          a.goes_after[b] = size

  def ComputePatchesForInputList(self, diff_queue, compress_target):
    """Returns a list of patch information for the input list of transfers.

      Args:
        diff_queue: a list of transfers with style 'diff'
        compress_target: If True, compresses the target ranges of each
            transfers; and save the size.

      Returns:
        A list of (transfer order, patch_info, compressed_size) tuples.
    """

    if not diff_queue:
      return []

    if self.threads > 1:
      logger.info("Computing patches (using %d threads)...", self.threads)
    else:
      logger.info("Computing patches...")

    diff_total = len(diff_queue)
    patches = [None] * diff_total
    error_messages = []

    # Using multiprocessing doesn't give additional benefits, due to the
    # pattern of the code. The diffing work is done by subprocess.call, which
    # already runs in a separate process (not affected much by the GIL -
    # Global Interpreter Lock). Using multiprocess also requires either a)
    # writing the diff input files in the main process before forking, or b)
    # reopening the image file (SparseImage) in the worker processes. Doing
    # neither of them further improves the performance.
    lock = threading.Lock()

    def diff_worker():
      while True:
        with lock:
          if not diff_queue:
            return
          xf_index, imgdiff, patch_index = diff_queue.pop()
          xf = self.transfers[xf_index]

        message = []
        compressed_size = None

        patch_info = xf.patch_info
        if not patch_info:
          src_file = common.MakeTempFile(prefix="src-")
          with open(src_file, "wb") as fd:
            self.src.WriteRangeDataToFd(xf.src_ranges, fd)

          tgt_file = common.MakeTempFile(prefix="tgt-")
          with open(tgt_file, "wb") as fd:
            self.tgt.WriteRangeDataToFd(xf.tgt_ranges, fd)

          try:
            patch_info = compute_patch(src_file, tgt_file, imgdiff)
          except ValueError as e:
            message.append(
                "Failed to generate %s for %s: tgt=%s, src=%s:\n%s" % (
                    "imgdiff" if imgdiff else "bsdiff",
                    xf.tgt_name if xf.tgt_name == xf.src_name else
                    xf.tgt_name + " (from " + xf.src_name + ")",
                    xf.tgt_ranges, xf.src_ranges, e.message))

        if compress_target:
          tgt_data = self.tgt.ReadRangeSet(xf.tgt_ranges)
          try:
            # Compresses with the default level
            compress_obj = zlib.compressobj(6, zlib.DEFLATED, -zlib.MAX_WBITS)
            compressed_data = (compress_obj.compress("".join(tgt_data))
                               + compress_obj.flush())
            compressed_size = len(compressed_data)
          except zlib.error as e:
            message.append(
                "Failed to compress the data in target range {} for {}:\n"
                "{}".format(xf.tgt_ranges, xf.tgt_name, e.message))

        if message:
          with lock:
            error_messages.extend(message)

        with lock:
          patches[patch_index] = (xf_index, patch_info, compressed_size)

    threads = [threading.Thread(target=diff_worker)
               for _ in range(self.threads)]
    for th in threads:
      th.start()
    while threads:
      threads.pop().join()

    if error_messages:
      logger.error('ERROR:')
      logger.error('\n'.join(error_messages))
      logger.error('\n\n\n')
      sys.exit(1)

    return patches

  def SelectAndConvertDiffTransfersToNew(self, violated_stash_blocks):
    """Converts the diff transfers to reduce the max simultaneous stash.

    Since the 'new' data is compressed with deflate, we can select the 'diff'
    transfers for conversion by comparing its patch size with the size of the
    compressed data. Ideally, we want to convert the transfers with a small
    size increase, but using a large number of stashed blocks.
    """
    TransferSizeScore = namedtuple("TransferSizeScore",
                                   "xf, used_stash_blocks, score")

    logger.info("Selecting diff commands to convert to new.")
    diff_queue = []
    for xf in self.transfers:
      if xf.style == "diff" and xf.src_sha1 != xf.tgt_sha1:
        use_imgdiff = self.CanUseImgdiff(xf.tgt_name, xf.tgt_ranges,
                                         xf.src_ranges)
        diff_queue.append((xf.order, use_imgdiff, len(diff_queue)))

    # Remove the 'move' transfers, and compute the patch & compressed size
    # for the remaining.
    result = self.ComputePatchesForInputList(diff_queue, True)

    conversion_candidates = []
    for xf_index, patch_info, compressed_size in result:
      xf = self.transfers[xf_index]
      if not xf.patch_info:
        xf.patch_info = patch_info

      size_ratio = len(xf.patch_info.content) * 100.0 / compressed_size
      diff_style = "imgdiff" if xf.patch_info.imgdiff else "bsdiff"
      logger.info("%s, target size: %d blocks, style: %s, patch size: %d,"
                  " compression_size: %d, ratio %.2f%%", xf.tgt_name,
                  xf.tgt_ranges.size(), diff_style,
                  len(xf.patch_info.content), compressed_size, size_ratio)

      used_stash_blocks = sum(sr.size() for _, sr in xf.use_stash)
      # Convert the transfer to new if the compressed size is smaller or equal.
      # We don't need to maintain the stash_before lists here because the
      # graph will be regenerated later.
      if len(xf.patch_info.content) >= compressed_size:
        # Add the transfer to the candidate list with negative score. And it
        # will be converted later.
        conversion_candidates.append(TransferSizeScore(xf, used_stash_blocks,
                                                       -1))
      elif used_stash_blocks > 0:
        # This heuristic represents the size increase in the final package to
        # remove per unit of stashed data.
        score = ((compressed_size - len(xf.patch_info.content)) * 100.0
                 / used_stash_blocks)
        conversion_candidates.append(TransferSizeScore(xf, used_stash_blocks,
                                                       score))
    # Transfers with lower score (i.e. less expensive to convert) will be
    # converted first.
    conversion_candidates.sort(key=lambda x: x.score)

    # TODO(xunchang), improve the logic to find the transfers to convert, e.g.
    # convert the ones that contribute to the max stash, run ReviseStashSize
    # multiple times etc.
    removed_stashed_blocks = 0
    for xf, used_stash_blocks, _ in conversion_candidates:
      logger.info("Converting %s to new", xf.tgt_name)
      xf.ConvertToNew()
      removed_stashed_blocks += used_stash_blocks
      # Experiments show that we will get a smaller package size if we remove
      # slightly more stashed blocks than the violated stash blocks.
      if removed_stashed_blocks >= violated_stash_blocks:
        break

    logger.info("Removed %d stashed blocks", removed_stashed_blocks)

  def FindTransfers(self):
    """Parse the file_map to generate all the transfers."""

    def AddSplitTransfersWithFixedSizeChunks(tgt_name, src_name, tgt_ranges,
                                             src_ranges, style, by_id):
      """Add one or multiple Transfer()s by splitting large files.

      For BBOTA v3, we need to stash source blocks for resumable feature.
      However, with the growth of file size and the shrink of the cache
      partition source blocks are too large to be stashed. If a file occupies
      too many blocks, we split it into smaller pieces by getting multiple
      Transfer()s.

      The downside is that after splitting, we may increase the package size
      since the split pieces don't align well. According to our experiments,
      1/8 of the cache size as the per-piece limit appears to be optimal.
      Compared to the fixed 1024-block limit, it reduces the overall package
      size by 30% for volantis, and 20% for angler and bullhead."""

      pieces = 0
      while (tgt_ranges.size() > max_blocks_per_transfer and
             src_ranges.size() > max_blocks_per_transfer):
        tgt_split_name = "%s-%d" % (tgt_name, pieces)
        src_split_name = "%s-%d" % (src_name, pieces)
        tgt_first = tgt_ranges.first(max_blocks_per_transfer)
        src_first = src_ranges.first(max_blocks_per_transfer)

        Transfer(tgt_split_name, src_split_name, tgt_first, src_first,
                 self.tgt.RangeSha1(tgt_first), self.src.RangeSha1(src_first),
                 style, by_id)

        tgt_ranges = tgt_ranges.subtract(tgt_first)
        src_ranges = src_ranges.subtract(src_first)
        pieces += 1

      # Handle remaining blocks.
      if tgt_ranges.size() or src_ranges.size():
        # Must be both non-empty.
        assert tgt_ranges.size() and src_ranges.size()
        tgt_split_name = "%s-%d" % (tgt_name, pieces)
        src_split_name = "%s-%d" % (src_name, pieces)
        Transfer(tgt_split_name, src_split_name, tgt_ranges, src_ranges,
                 self.tgt.RangeSha1(tgt_ranges), self.src.RangeSha1(src_ranges),
                 style, by_id)

    def AddSplitTransfers(tgt_name, src_name, tgt_ranges, src_ranges, style,
                          by_id):
      """Find all the zip files and split the others with a fixed chunk size.

      This function will construct a list of zip archives, which will later be
      split by imgdiff to reduce the final patch size. For the other files,
      we will plainly split them based on a fixed chunk size with the potential
      patch size penalty.
      """

      assert style == "diff"

      # Change nothing for small files.
      if (tgt_ranges.size() <= max_blocks_per_transfer and
          src_ranges.size() <= max_blocks_per_transfer):
        Transfer(tgt_name, src_name, tgt_ranges, src_ranges,
                 self.tgt.RangeSha1(tgt_ranges), self.src.RangeSha1(src_ranges),
                 style, by_id)
        return

      # Split large APKs with imgdiff, if possible. We're intentionally checking
      # file types one more time (CanUseImgdiff() checks that as well), before
      # calling the costly RangeSha1()s.
      if (self.FileTypeSupportedByImgdiff(tgt_name) and
          self.tgt.RangeSha1(tgt_ranges) != self.src.RangeSha1(src_ranges)):
        if self.CanUseImgdiff(tgt_name, tgt_ranges, src_ranges, True):
          large_apks.append((tgt_name, src_name, tgt_ranges, src_ranges))
          return

      AddSplitTransfersWithFixedSizeChunks(tgt_name, src_name, tgt_ranges,
                                           src_ranges, style, by_id)

    def AddTransfer(tgt_name, src_name, tgt_ranges, src_ranges, style, by_id,
                    split=False):
      """Wrapper function for adding a Transfer()."""

      # We specialize diff transfers only (which covers bsdiff/imgdiff/move);
      # otherwise add the Transfer() as is.
      if style != "diff" or not split:
        Transfer(tgt_name, src_name, tgt_ranges, src_ranges,
                 self.tgt.RangeSha1(tgt_ranges), self.src.RangeSha1(src_ranges),
                 style, by_id)
        return

      # Handle .odex files specially to analyze the block-wise difference. If
      # most of the blocks are identical with only few changes (e.g. header),
      # we will patch the changed blocks only. This avoids stashing unchanged
      # blocks while patching. We limit the analysis to files without size
      # changes only. This is to avoid sacrificing the OTA generation cost too
      # much.
      if (tgt_name.split(".")[-1].lower() == 'odex' and
          tgt_ranges.size() == src_ranges.size()):

        # 0.5 threshold can be further tuned. The tradeoff is: if only very
        # few blocks remain identical, we lose the opportunity to use imgdiff
        # that may have better compression ratio than bsdiff.
        crop_threshold = 0.5

        tgt_skipped = RangeSet()
        src_skipped = RangeSet()
        tgt_size = tgt_ranges.size()
        tgt_changed = 0
        for src_block, tgt_block in zip(src_ranges.next_item(),
                                        tgt_ranges.next_item()):
          src_rs = RangeSet(str(src_block))
          tgt_rs = RangeSet(str(tgt_block))
          if self.src.ReadRangeSet(src_rs) == self.tgt.ReadRangeSet(tgt_rs):
            tgt_skipped = tgt_skipped.union(tgt_rs)
            src_skipped = src_skipped.union(src_rs)
          else:
            tgt_changed += tgt_rs.size()

          # Terminate early if no clear sign of benefits.
          if tgt_changed > tgt_size * crop_threshold:
            break

        if tgt_changed < tgt_size * crop_threshold:
          assert tgt_changed + tgt_skipped.size() == tgt_size
          logger.info(
              '%10d %10d (%6.2f%%) %s', tgt_skipped.size(), tgt_size,
              tgt_skipped.size() * 100.0 / tgt_size, tgt_name)
          AddSplitTransfers(
              "%s-skipped" % (tgt_name,),
              "%s-skipped" % (src_name,),
              tgt_skipped, src_skipped, style, by_id)

          # Intentionally change the file extension to avoid being imgdiff'd as
          # the files are no longer in their original format.
          tgt_name = "%s-cropped" % (tgt_name,)
          src_name = "%s-cropped" % (src_name,)
          tgt_ranges = tgt_ranges.subtract(tgt_skipped)
          src_ranges = src_ranges.subtract(src_skipped)

          # Possibly having no changed blocks.
          if not tgt_ranges:
            return

      # Add the transfer(s).
      AddSplitTransfers(
          tgt_name, src_name, tgt_ranges, src_ranges, style, by_id)

    def ParseAndValidateSplitInfo(patch_size, tgt_ranges, src_ranges,
                                  split_info):
      """Parse the split_info and return a list of info tuples.

      Args:
        patch_size: total size of the patch file.
        tgt_ranges: Ranges of the target file within the original image.
        src_ranges: Ranges of the source file within the original image.
        split_info format:
          imgdiff version#
          count of pieces
          <patch_size_1> <tgt_size_1> <src_ranges_1>
          ...
          <patch_size_n> <tgt_size_n> <src_ranges_n>

      Returns:
        [patch_start, patch_len, split_tgt_ranges, split_src_ranges]
      """

      version = int(split_info[0])
      assert version == 2
      count = int(split_info[1])
      assert len(split_info) - 2 == count

      split_info_list = []
      patch_start = 0
      tgt_remain = copy.deepcopy(tgt_ranges)
      # each line has the format <patch_size>, <tgt_size>, <src_ranges>
      for line in split_info[2:]:
        info = line.split()
        assert len(info) == 3
        patch_length = int(info[0])

        split_tgt_size = int(info[1])
        assert split_tgt_size % 4096 == 0
        assert split_tgt_size // 4096 <= tgt_remain.size()
        split_tgt_ranges = tgt_remain.first(split_tgt_size // 4096)
        tgt_remain = tgt_remain.subtract(split_tgt_ranges)

        # Find the split_src_ranges within the image file from its relative
        # position in file.
        split_src_indices = RangeSet.parse_raw(info[2])
        split_src_ranges = RangeSet()
        for r in split_src_indices:
          curr_range = src_ranges.first(r[1]).subtract(src_ranges.first(r[0]))
          assert not split_src_ranges.overlaps(curr_range)
          split_src_ranges = split_src_ranges.union(curr_range)

        split_info_list.append((patch_start, patch_length,
                                split_tgt_ranges, split_src_ranges))
        patch_start += patch_length

      # Check that the sizes of all the split pieces add up to the final file
      # size for patch and target.
      assert tgt_remain.size() == 0
      assert patch_start == patch_size
      return split_info_list

    def SplitLargeApks():
      """Split the large apks files.

      Example: Chrome.apk will be split into
        src-0: Chrome.apk-0, tgt-0: Chrome.apk-0
        src-1: Chrome.apk-1, tgt-1: Chrome.apk-1
        ...

      After the split, the target pieces are continuous and block aligned; and
      the source pieces are mutually exclusive. During the split, we also
      generate and save the image patch between src-X & tgt-X. This patch will
      be valid because the block ranges of src-X & tgt-X will always stay the
      same afterwards; but there's a chance we don't use the patch if we
      convert the "diff" command into "new" or "move" later.
      """

      while True:
        with transfer_lock:
          if not large_apks:
            return
          tgt_name, src_name, tgt_ranges, src_ranges = large_apks.pop(0)

        src_file = common.MakeTempFile(prefix="src-")
        tgt_file = common.MakeTempFile(prefix="tgt-")
        with open(src_file, "wb") as src_fd:
          self.src.WriteRangeDataToFd(src_ranges, src_fd)
        with open(tgt_file, "wb") as tgt_fd:
          self.tgt.WriteRangeDataToFd(tgt_ranges, tgt_fd)

        patch_file = common.MakeTempFile(prefix="patch-")
        patch_info_file = common.MakeTempFile(prefix="split_info-")
        cmd = ["imgdiff", "-z",
               "--block-limit={}".format(max_blocks_per_transfer),
               "--split-info=" + patch_info_file,
               src_file, tgt_file, patch_file]
        proc = common.Run(cmd)
        imgdiff_output, _ = proc.communicate()
        assert proc.returncode == 0, \
            "Failed to create imgdiff patch between {} and {}:\n{}".format(
                src_name, tgt_name, imgdiff_output)

        with open(patch_info_file) as patch_info:
          lines = patch_info.readlines()

        patch_size_total = os.path.getsize(patch_file)
        split_info_list = ParseAndValidateSplitInfo(patch_size_total,
                                                    tgt_ranges, src_ranges,
                                                    lines)
        for index, (patch_start, patch_length, split_tgt_ranges,
                    split_src_ranges) in enumerate(split_info_list):
          with open(patch_file, 'rb') as f:
            f.seek(patch_start)
            patch_content = f.read(patch_length)

          split_src_name = "{}-{}".format(src_name, index)
          split_tgt_name = "{}-{}".format(tgt_name, index)
          split_large_apks.append((split_tgt_name,
                                   split_src_name,
                                   split_tgt_ranges,
                                   split_src_ranges,
                                   patch_content))

    logger.info("Finding transfers...")

    large_apks = []
    split_large_apks = []
    cache_size = common.OPTIONS.cache_size
    split_threshold = 0.125
    max_blocks_per_transfer = int(cache_size * split_threshold /
                                  self.tgt.blocksize)
    empty = RangeSet()
    for tgt_fn, tgt_ranges in sorted(self.tgt.file_map.items()):
      if tgt_fn == "__ZERO":
        # the special "__ZERO" domain is all the blocks not contained
        # in any file and that are filled with zeros.  We have a
        # special transfer style for zero blocks.
        src_ranges = self.src.file_map.get("__ZERO", empty)
        AddTransfer(tgt_fn, "__ZERO", tgt_ranges, src_ranges,
                    "zero", self.transfers)
        continue

      elif tgt_fn == "__COPY":
        # "__COPY" domain includes all the blocks not contained in any
        # file and that need to be copied unconditionally to the target.
        AddTransfer(tgt_fn, None, tgt_ranges, empty, "new", self.transfers)
        continue

      elif tgt_fn == "__HASHTREE":
        continue

      elif tgt_fn in self.src.file_map:
        # Look for an exact pathname match in the source.
        AddTransfer(tgt_fn, tgt_fn, tgt_ranges, self.src.file_map[tgt_fn],
                    "diff", self.transfers, True)
        continue

      b = os.path.basename(tgt_fn)
      if b in self.src_basenames:
        # Look for an exact basename match in the source.
        src_fn = self.src_basenames[b]
        AddTransfer(tgt_fn, src_fn, tgt_ranges, self.src.file_map[src_fn],
                    "diff", self.transfers, True)
        continue

      b = re.sub("[0-9]+", "#", b)
      if b in self.src_numpatterns:
        # Look for a 'number pattern' match (a basename match after
        # all runs of digits are replaced by "#").  (This is useful
        # for .so files that contain version numbers in the filename
        # that get bumped.)
        src_fn = self.src_numpatterns[b]
        AddTransfer(tgt_fn, src_fn, tgt_ranges, self.src.file_map[src_fn],
                    "diff", self.transfers, True)
        continue

      AddTransfer(tgt_fn, None, tgt_ranges, empty, "new", self.transfers)

    transfer_lock = threading.Lock()
    threads = [threading.Thread(target=SplitLargeApks)
               for _ in range(self.threads)]
    for th in threads:
      th.start()
    while threads:
      threads.pop().join()

    # Sort the split transfers for large apks to generate a determinate package.
    split_large_apks.sort()
    for (tgt_name, src_name, tgt_ranges, src_ranges,
         patch) in split_large_apks:
      transfer_split = Transfer(tgt_name, src_name, tgt_ranges, src_ranges,
                                self.tgt.RangeSha1(tgt_ranges),
                                self.src.RangeSha1(src_ranges),
                                "diff", self.transfers)
      transfer_split.patch_info = PatchInfo(True, patch)

  def AbbreviateSourceNames(self):
    for k in self.src.file_map.keys():
      b = os.path.basename(k)
      self.src_basenames[b] = k
      b = re.sub("[0-9]+", "#", b)
      self.src_numpatterns[b] = k

  @staticmethod
  def AssertPartition(total, seq):
    """Assert that all the RangeSets in 'seq' form a partition of the
    'total' RangeSet (ie, they are nonintersecting and their union
    equals 'total')."""

    so_far = RangeSet()
    for i in seq:
      assert not so_far.overlaps(i)
      so_far = so_far.union(i)
    assert so_far == total
