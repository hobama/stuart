local _ = require 'lodash'
local moses = require 'moses'
local registerAsserts = require 'registerAsserts'
local stuart = require 'stuart'

registerAsserts(assert)

describe('Apache Spark 2.2.0 RDDSuite', function()

  local sc = stuart.NewContext()

  local split = function(str, sep)
    local fields = {}
    local pattern = string.format('([^%s]+)', sep)
    str:gsub(pattern, function(c) fields[#fields+1] = c end)
    return fields
  end

  it('basic operations', function()
    local nums = sc:makeRDD({1,2,3,4}, 2)
    assert.equals(2, #nums.partitions)
    assert.same({1,2,3,4}, nums:collect())
    assert.same({1,2,3,4}, moses.array(nums:toLocalIterator()))
    local dups = sc:makeRDD({1,1,2,2,3,3,4,4}, 2)
    assert.equals(4, dups:distinct():count())
    assert.equals(4, dups:distinct():count())
    assert.same(dups:distinct():collect(), dups:distinct():collect())
    assert.same(dups:distinct():collect(), dups:distinct(2):collect())
    assert.equals(10, nums:reduce(function(r, x) return r+x end))
    assert.equals(10, nums:fold(0, function(a,b) return a+b end))
    assert.same({'1','2','3','4'}, nums:map(_.str):collect())
    assert.same({3,4}, nums:filter(function(x) return x > 2 end):collect())
    assert.same({1,1,2,1,2,3,1,2,3,4}, nums:flatMap(function(x) return _.range(x) end):collect())
    assert.same({1,2,3,4,1,2,3,4}, nums:union(nums):collect())
    assert.same({{1,2},{3,4}}, nums:glom():map(_.flatten):collect())
    assert.same({'3','4'}, nums:collect(function(i) if i >= 3 then return _.str(i) end end))
    assert.same({{'1',1}, {'2',2}, {'3',3}, {'4',4}}, nums:keyBy(_.str):collect())
    assert.is_false(nums:isEmpty())
    assert.equals(4, nums:max())
    assert.equals(1, nums:min())
    
    local partitionSums = nums:mapPartitions(function(iter)
      local sum = 0
      for v in iter do sum = sum + v end
      local i = 0 
      return function()
        i = i + 1
        if i == 1 then return sum end
      end
    end)
    assert.same({3,7}, partitionSums:collect())

    local partitionSumsWithSplit = nums:mapPartitionsWithIndex(function(split, iter)
      local sum = 0
      for v in iter do sum = sum + v end
      local i = 0 
      return function()
        i = i + 1
        if i == 1 then return {split, sum} end
      end
    end)
    assert.contains_pair(partitionSumsWithSplit:collect(), {0,3})
    assert.contains_pair(partitionSumsWithSplit:collect(), {1,7})
  end)

--  test("serialization") {
--    val empty = new EmptyRDD[Int](sc)
--    val serial = Utils.serialize(empty)
--    val deserial: EmptyRDD[Int] = Utils.deserialize(serial)
--    assert(!deserial.toString().isEmpty())
--  }

--  test("countApproxDistinct") {
--
--    def error(est: Long, size: Long): Double = math.abs(est - size) / size.toDouble
--
--    val size = 1000
--    val uniformDistro = for (i <- 1 to 5000) yield i % size
--    val simpleRdd = sc.makeRDD(uniformDistro, 10)
--    assert(error(simpleRdd.countApproxDistinct(8, 0), size) < 0.2)
--    assert(error(simpleRdd.countApproxDistinct(12, 0), size) < 0.1)
--    assert(error(simpleRdd.countApproxDistinct(0.02), size) < 0.1)
--    assert(error(simpleRdd.countApproxDistinct(0.5), size) < 0.22)
--  }

  it('SparkContext.union', function()
    local nums = sc:makeRDD({1, 2, 3, 4}, 2)
    assert.same({1, 2, 3, 4}, sc:union({nums}):collect())
    assert.same({1, 2, 3, 4, 1, 2, 3, 4}, sc:union({nums, nums}):collect())
    --Scala-specific: assert.same({1, 2, 3, 4}, sc:union(Seq(nums)):collect())
    --Scala-specific: assert.same({1, 2, 3, 4, 1, 2, 3, 4}, sc:union(Seq(nums, nums)):collect())
  end)

--  test("SparkContext.union parallel partition listing") {
--    val nums1 = sc.makeRDD(Array(1, 2, 3, 4), 2)
--    val nums2 = sc.makeRDD(Array(5, 6, 7, 8), 2)
--    val serialUnion = sc.union(nums1, nums2)
--    val expected = serialUnion.collect().toList
--
--    assert(serialUnion.asInstanceOf[UnionRDD[Int]].isPartitionListingParallel === false)
--
--    sc.conf.set("spark.rdd.parallelListingThreshold", "1")
--    val parallelUnion = sc.union(nums1, nums2)
--    val actual = parallelUnion.collect().toList
--    sc.conf.remove("spark.rdd.parallelListingThreshold")
--
--    assert(parallelUnion.asInstanceOf[UnionRDD[Int]].isPartitionListingParallel === true)
--    assert(expected === actual)
--  }

--  test("SparkContext.union creates UnionRDD if at least one RDD has no partitioner") {
--    val rddWithPartitioner = sc.parallelize(Seq(1 -> true)).partitionBy(new HashPartitioner(1))
--    val rddWithNoPartitioner = sc.parallelize(Seq(2 -> true))
--    val unionRdd = sc.union(rddWithNoPartitioner, rddWithPartitioner)
--    assert(unionRdd.isInstanceOf[UnionRDD[_]])
--  }

--  test("SparkContext.union creates PartitionAwareUnionRDD if all RDDs have partitioners") {
--    val rddWithPartitioner = sc.parallelize(Seq(1 -> true)).partitionBy(new HashPartitioner(1))
--    val unionRdd = sc.union(rddWithPartitioner, rddWithPartitioner)
--    assert(unionRdd.isInstanceOf[PartitionerAwareUnionRDD[_]])
--  }

--  test("PartitionAwareUnionRDD raises exception if at least one RDD has no partitioner") {
--    val rddWithPartitioner = sc.parallelize(Seq(1 -> true)).partitionBy(new HashPartitioner(1))
--    val rddWithNoPartitioner = sc.parallelize(Seq(2 -> true))
--    intercept[IllegalArgumentException] {
--      new PartitionerAwareUnionRDD(sc, Seq(rddWithNoPartitioner, rddWithPartitioner))
--    }
--  }

--  test("partitioner aware union") {
--    def makeRDDWithPartitioner(seq: Seq[Int]): RDD[Int] = {
--      sc.makeRDD(seq, 1)
--        .map(x => (x, null))
--        .partitionBy(new HashPartitioner(2))
--        .mapPartitions(_.map(_._1), true)
--    }
--
--    val nums1 = makeRDDWithPartitioner(1 to 4)
--    val nums2 = makeRDDWithPartitioner(5 to 8)
--    assert(nums1.partitioner == nums2.partitioner)
--    assert(new PartitionerAwareUnionRDD(sc, Seq(nums1)).collect().toSet === Set(1, 2, 3, 4))
--
--    val union = new PartitionerAwareUnionRDD(sc, Seq(nums1, nums2))
--    assert(union.collect().toSet === Set(1, 2, 3, 4, 5, 6, 7, 8))
--    val nums1Parts = nums1.collectPartitions()
--    val nums2Parts = nums2.collectPartitions()
--    val unionParts = union.collectPartitions()
--    assert(nums1Parts.length === 2)
--    assert(nums2Parts.length === 2)
--    assert(unionParts.length === 2)
--    assert((nums1Parts(0) ++ nums2Parts(0)).toList === unionParts(0).toList)
--    assert((nums1Parts(1) ++ nums2Parts(1)).toList === unionParts(1).toList)
--    assert(union.partitioner === nums1.partitioner)
--  }

--  test("UnionRDD partition serialized size should be small") {
--    val largeVariable = new Array[Byte](1000 * 1000)
--    val rdd1 = sc.parallelize(1 to 10, 2).map(i => largeVariable.length)
--    val rdd2 = sc.parallelize(1 to 10, 3)
--
--    val ser = SparkEnv.get.closureSerializer.newInstance()
--    val union = rdd1.union(rdd2)
--    // The UnionRDD itself should be large, but each individual partition should be small.
--    assert(ser.serialize(union).limit() > 2000)
--    assert(ser.serialize(union.partitions.head).limit() < 2000)
--  }

  -- translation of this test to Lua avoids the variable name "pair"
  it('aggregate', function()
    local pairsrdd = sc:makeRDD({{'a',1}, {'b',2}, {'a',2}, {'c',5}, {'a',3}}, 2)
    local mergeElement = function(map, pairrdd)
      map[pairrdd[1]] = (map[pairrdd[1]] or 0) + pairrdd[2]
      return map
    end
    local mergeMaps = function(map1, map2)
      local r = map1
      for key,value in pairs(map2) do
        r[key] = (r[key] or 0) + value 
      end
      return r
    end
    local result = pairsrdd:aggregate({}, mergeElement, mergeMaps)
    assert.equals(6, result['a'])
    assert.equals(2, result['b'])
    assert.equals(5, result['c'])
  end)

--  test("treeAggregate") {
--    val rdd = sc.makeRDD(-1000 until 1000, 10)
--    def seqOp: (Long, Int) => Long = (c: Long, x: Int) => c + x
--    def combOp: (Long, Long) => Long = (c1: Long, c2: Long) => c1 + c2
--    for (depth <- 1 until 10) {
--      val sum = rdd.treeAggregate(0L)(seqOp, combOp, depth)
--      assert(sum === -1000L)
--    }
--  }

--  test("treeReduce") {
--    val rdd = sc.makeRDD(-1000 until 1000, 10)
--    for (depth <- 1 until 10) {
--      val sum = rdd.treeReduce(_ + _, depth)
--      assert(sum === -1000)
--    }
--  }

  it('basic caching', function()
    local rdd = sc:makeRDD({1,2,3,4}, 2):cache()
    assert.same({1,2,3,4}, rdd:collect())
    assert.same({1,2,3,4}, rdd:collect())
    assert.same({1,2,3,4}, rdd:collect())
  end)

--  test("caching with failures") {
--    val onlySplit = new Partition { override def index: Int = 0 }
--    var shouldFail = true
--    val rdd = new RDD[Int](sc, Nil) {
--      override def getPartitions: Array[Partition] = Array(onlySplit)
--      override val getDependencies = List[Dependency[_]]()
--      override def compute(split: Partition, context: TaskContext): Iterator[Int] = {
--        throw new Exception("injected failure")
--      }
--    }.cache()
--    val thrown = intercept[Exception]{
--      rdd.collect()
--    }
--    assert(thrown.getMessage.contains("injected failure"))
--  }

--  test("empty RDD") {
--    val empty = new EmptyRDD[Int](sc)
--    assert(empty.count === 0)
--    assert(empty.collect().size === 0)
--
--    val thrown = intercept[UnsupportedOperationException]{
--      empty.reduce(_ + _)
--    }
--    assert(thrown.getMessage.contains("empty"))
--
--    val emptyKv = new EmptyRDD[(Int, Int)](sc)
--    val rdd = sc.parallelize(1 to 2, 2).map(x => (x, x))
--    assert(rdd.join(emptyKv).collect().size === 0)
--    assert(rdd.rightOuterJoin(emptyKv).collect().size === 0)
--    assert(rdd.leftOuterJoin(emptyKv).collect().size === 2)
--    assert(rdd.fullOuterJoin(emptyKv).collect().size === 2)
--    assert(rdd.cogroup(emptyKv).collect().size === 2)
--    assert(rdd.union(emptyKv).collect().size === 2)
--  }

  it('repartitioned RDDs', function()
    local data = sc:parallelize(_.range(1, 1000), 10)
    
    -- Coalesce partitions
    local repartitioned1 = data:repartition(2)
    assert.equals(2, #repartitioned1.partitions)
    local partitions1 = repartitioned1:glom():collect()
    assert.is_true(#partitions1[1] > 0)
    assert.is_true(#partitions1[2] > 0)
    assert.same(_.range(1, 1000), repartitioned1:collect())
    
    -- Split partitions
    local repartitioned2 = data:repartition(20)
    assert(20, #repartitioned2.partitions)
    local partitions2 = repartitioned2:glom():collect()
    assert.is_true(#partitions2[1] > 0)
    assert.is_true(#partitions2[20] > 0)
    assert.same(_.range(1, 1000), repartitioned2:collect())
  end)

--  test("repartitioned RDDs perform load balancing") {
--    // Coalesce partitions
--    val input = Array.fill(1000)(1)
--    val initialPartitions = 10
--    val data = sc.parallelize(input, initialPartitions)
--
--    val repartitioned1 = data.repartition(2)
--    assert(repartitioned1.partitions.size == 2)
--    val partitions1 = repartitioned1.glom().collect()
--    // some noise in balancing is allowed due to randomization
--    assert(math.abs(partitions1(0).length - 500) < initialPartitions)
--    assert(math.abs(partitions1(1).length - 500) < initialPartitions)
--    assert(repartitioned1.collect() === input)
--
--    def testSplitPartitions(input: Seq[Int], initialPartitions: Int, finalPartitions: Int) {
--      val data = sc.parallelize(input, initialPartitions)
--      val repartitioned = data.repartition(finalPartitions)
--      assert(repartitioned.partitions.size === finalPartitions)
--      val partitions = repartitioned.glom().collect()
--      // assert all elements are present
--      assert(repartitioned.collect().sortWith(_ > _).toSeq === input.toSeq.sortWith(_ > _).toSeq)
--      // assert no bucket is overloaded
--      for (partition <- partitions) {
--        val avg = input.size / finalPartitions
--        val maxPossible = avg + initialPartitions
--        assert(partition.length <=  maxPossible)
--      }
--    }
--
--    testSplitPartitions(Array.fill(100)(1), 10, 20)
--    testSplitPartitions(Array.fill(10000)(1) ++ Array.fill(10000)(2), 20, 100)
--  }

--  test("coalesced RDDs") {
--    val data = sc.parallelize(1 to 10, 10)
--
--    intercept[IllegalArgumentException] {
--      data.coalesce(0)
--    }
--
--    val coalesced1 = data.coalesce(2)
--    assert(coalesced1.collect().toList === (1 to 10).toList)
--    assert(coalesced1.glom().collect().map(_.toList).toList ===
--      List(List(1, 2, 3, 4, 5), List(6, 7, 8, 9, 10)))
--
--    // Check that the narrow dependency is also specified correctly
--    assert(coalesced1.dependencies.head.asInstanceOf[NarrowDependency[_]].getParents(0).toList ===
--      List(0, 1, 2, 3, 4))
--    assert(coalesced1.dependencies.head.asInstanceOf[NarrowDependency[_]].getParents(1).toList ===
--      List(5, 6, 7, 8, 9))
--
--    val coalesced2 = data.coalesce(3)
--    assert(coalesced2.collect().toList === (1 to 10).toList)
--    assert(coalesced2.glom().collect().map(_.toList).toList ===
--      List(List(1, 2, 3), List(4, 5, 6), List(7, 8, 9, 10)))
--
--    val coalesced3 = data.coalesce(10)
--    assert(coalesced3.collect().toList === (1 to 10).toList)
--    assert(coalesced3.glom().collect().map(_.toList).toList ===
--      (1 to 10).map(x => List(x)).toList)
--
--    // If we try to coalesce into more partitions than the original RDD, it should just
--    // keep the original number of partitions.
--    val coalesced4 = data.coalesce(20)
--    assert(coalesced4.collect().toList === (1 to 10).toList)
--    assert(coalesced4.glom().collect().map(_.toList).toList ===
--      (1 to 10).map(x => List(x)).toList)
--
--    // we can optionally shuffle to keep the upstream parallel
--    val coalesced5 = data.coalesce(1, shuffle = true)
--    val isEquals = coalesced5.dependencies.head.rdd.dependencies.head.rdd.
--      asInstanceOf[ShuffledRDD[_, _, _]] != null
--    assert(isEquals)
--
--    // when shuffling, we can increase the number of partitions
--    val coalesced6 = data.coalesce(20, shuffle = true)
--    assert(coalesced6.partitions.size === 20)
--    assert(coalesced6.collect().toSet === (1 to 10).toSet)
--  }

--  test("coalesced RDDs with locality") {
--    val data3 = sc.makeRDD(List((1, List("a", "c")), (2, List("a", "b", "c")), (3, List("b"))))
--    val coal3 = data3.coalesce(3)
--    val list3 = coal3.partitions.flatMap(_.asInstanceOf[CoalescedRDDPartition].preferredLocation)
--    assert(list3.sorted === Array("a", "b", "c"), "Locality preferences are dropped")
--
--    // RDD with locality preferences spread (non-randomly) over 6 machines, m0 through m5
--    val data = sc.makeRDD((1 to 9).map(i => (i, (i to (i + 2)).map{ j => "m" + (j%6)})))
--    val coalesced1 = data.coalesce(3)
--    assert(coalesced1.collect().toList.sorted === (1 to 9).toList, "Data got *lost* in coalescing")
--
--    val splits = coalesced1.glom().collect().map(_.toList).toList
--    assert(splits.length === 3, "Supposed to coalesce to 3 but got " + splits.length)
--
--    assert(splits.forall(_.length >= 1) === true, "Some partitions were empty")
--
--    // If we try to coalesce into more partitions than the original RDD, it should just
--    // keep the original number of partitions.
--    val coalesced4 = data.coalesce(20)
--    val listOfLists = coalesced4.glom().collect().map(_.toList).toList
--    val sortedList = listOfLists.sortWith{ (x, y) => !x.isEmpty && (y.isEmpty || (x(0) < y(0))) }
--    assert(sortedList === (1 to 9).
--      map{x => List(x)}.toList, "Tried coalescing 9 partitions to 20 but didn't get 9 back")
--  }

-- test("coalesced RDDs with partial locality") {
--    // Make an RDD that has some locality preferences and some without. This can happen
--    // with UnionRDD
--    val data = sc.makeRDD((1 to 9).map(i => {
--      if (i > 4) {
--        (i, (i to (i + 2)).map { j => "m" + (j % 6) })
--      } else {
--        (i, Vector())
--      }
--    }))
--    val coalesced1 = data.coalesce(3)
--    assert(coalesced1.collect().toList.sorted === (1 to 9).toList, "Data got *lost* in coalescing")
--
--    val splits = coalesced1.glom().collect().map(_.toList).toList
--    assert(splits.length === 3, "Supposed to coalesce to 3 but got " + splits.length)
--
--    assert(splits.forall(_.length >= 1) === true, "Some partitions were empty")
--
--    // If we try to coalesce into more partitions than the original RDD, it should just
--    // keep the original number of partitions.
--    val coalesced4 = data.coalesce(20)
--    val listOfLists = coalesced4.glom().collect().map(_.toList).toList
--    val sortedList = listOfLists.sortWith{ (x, y) => !x.isEmpty && (y.isEmpty || (x(0) < y(0))) }
--    assert(sortedList === (1 to 9).
--      map{x => List(x)}.toList, "Tried coalescing 9 partitions to 20 but didn't get 9 back")
--  }

--  test("coalesced RDDs with locality, large scale (10K partitions)") {
--    // large scale experiment
--    import collection.mutable
--    val partitions = 10000
--    val numMachines = 50
--    val machines = mutable.ListBuffer[String]()
--    (1 to numMachines).foreach(machines += "m" + _)
--    val rnd = scala.util.Random
--    for (seed <- 1 to 5) {
--      rnd.setSeed(seed)
--
--      val blocks = (1 to partitions).map { i =>
--        (i, Array.fill(3)(machines(rnd.nextInt(machines.size))).toList)
--      }
--
--      val data2 = sc.makeRDD(blocks)
--      val coalesced2 = data2.coalesce(numMachines * 2)
--
--      // test that you get over 90% locality in each group
--      val minLocality = coalesced2.partitions
--        .map(part => part.asInstanceOf[CoalescedRDDPartition].localFraction)
--        .foldLeft(1.0)((perc, loc) => math.min(perc, loc))
--      assert(minLocality >= 0.90, "Expected 90% locality but got " +
--        (minLocality * 100.0).toInt + "%")
--
--      // test that the groups are load balanced with 100 +/- 20 elements in each
--      val maxImbalance = coalesced2.partitions
--        .map(part => part.asInstanceOf[CoalescedRDDPartition].parents.size)
--        .foldLeft(0)((dev, curr) => math.max(math.abs(100 - curr), dev))
--      assert(maxImbalance <= 20, "Expected 100 +/- 20 per partition, but got " + maxImbalance)
--
--      val data3 = sc.makeRDD(blocks).map(i => i * 2) // derived RDD to test *current* pref locs
--      val coalesced3 = data3.coalesce(numMachines * 2)
--      val minLocality2 = coalesced3.partitions
--        .map(part => part.asInstanceOf[CoalescedRDDPartition].localFraction)
--        .foldLeft(1.0)((perc, loc) => math.min(perc, loc))
--      assert(minLocality2 >= 0.90, "Expected 90% locality for derived RDD but got " +
--        (minLocality2 * 100.0).toInt + "%")
--    }
--  }

--  test("coalesced RDDs with partial locality, large scale (10K partitions)") {
--    // large scale experiment
--    import collection.mutable
--    val halfpartitions = 5000
--    val partitions = 10000
--    val numMachines = 50
--    val machines = mutable.ListBuffer[String]()
--    (1 to numMachines).foreach(machines += "m" + _)
--    val rnd = scala.util.Random
--    for (seed <- 1 to 5) {
--      rnd.setSeed(seed)
--
--      val firstBlocks = (1 to halfpartitions).map { i =>
--        (i, Array.fill(3)(machines(rnd.nextInt(machines.size))).toList)
--      }
--      val blocksNoLocality = (halfpartitions + 1 to partitions).map { i =>
--        (i, List())
--      }
--      val blocks = firstBlocks ++ blocksNoLocality
--
--      val data2 = sc.makeRDD(blocks)
--
--      // first try going to same number of partitions
--      val coalesced2 = data2.coalesce(partitions)
--
--      // test that we have 10000 partitions
--      assert(coalesced2.partitions.size == 10000, "Expected 10000 partitions, but got " +
--        coalesced2.partitions.size)
--
--      // test that we have 100 partitions
--      val coalesced3 = data2.coalesce(numMachines * 2)
--      assert(coalesced3.partitions.size == 100, "Expected 100 partitions, but got " +
--        coalesced3.partitions.size)
--
--      // test that the groups are load balanced with 100 +/- 20 elements in each
--      val maxImbalance3 = coalesced3.partitions
--        .map(part => part.asInstanceOf[CoalescedRDDPartition].parents.size)
--        .foldLeft(0)((dev, curr) => math.max(math.abs(100 - curr), dev))
--      assert(maxImbalance3 <= 20, "Expected 100 +/- 20 per partition, but got " + maxImbalance3)
--    }
--  }

  -- Test for SPARK-2412 -- ensure that the second pass of the algorithm does not throw an exception
--  test("coalesced RDDs with locality, fail first pass") {
--    val initialPartitions = 1000
--    val targetLen = 50
--    val couponCount = 2 * (math.log(targetLen)*targetLen + targetLen + 0.5).toInt // = 492
--
--    val blocks = (1 to initialPartitions).map { i =>
--      (i, List(if (i > couponCount) "m2" else "m1"))
--    }
--    val data = sc.makeRDD(blocks)
--    val coalesced = data.coalesce(targetLen)
--    assert(coalesced.partitions.length == targetLen)
--  }

--  test("zipped RDDs") {
--    val nums = sc.makeRDD(Array(1, 2, 3, 4), 2)
--    val zipped = nums.zip(nums.map(_ + 1.0))
--    assert(zipped.glom().map(_.toList).collect().toList ===
--      List(List((1, 2.0), (2, 3.0)), List((3, 4.0), (4, 5.0))))
--
--    intercept[IllegalArgumentException] {
--      nums.zip(sc.parallelize(1 to 4, 1)).collect()
--    }
--
--    intercept[SparkException] {
--      nums.zip(sc.parallelize(1 to 5, 2)).collect()
--    }
--  }

--  test("partition pruning") {
--    val data = sc.parallelize(1 to 10, 10)
--    // Note that split number starts from 0, so > 8 means only 10th partition left.
--    val prunedRdd = new PartitionPruningRDD(data, splitNum => splitNum > 8)
--    assert(prunedRdd.partitions.size === 1)
--    val prunedData = prunedRdd.collect()
--    assert(prunedData.size === 1)
--    assert(prunedData(0) === 10)
--  }

  -- Regression test for SPARK-4019
  it('collect large number of empty partitions', function()
    local expected = _.range(0,10)
    assert.same(expected, sc:makeRDD(_.range(0,10), 1000):repartition(2001):collect())
  end)

  it('take', function()
    local nums = sc:makeRDD(_.range(1, 999), 1) -- Scala Range would read 1,1000
    assert.same({}, nums:take(0))
    assert.same({1}, nums:take(1))
    assert.same({1,2,3}, nums:take(3))
    assert.same(_.range(1,500), nums:take(500))
    assert.same(_.range(1,501), nums:take(501))
    assert.same(_.range(1,999), nums:take(999))
    assert.same(_.range(1,999), nums:take(1000))

    nums = sc:makeRDD(_.range(1, 999), 2)
    assert.equals(0, #nums:take(0))
    assert.same({1}, nums:take(1))
    assert.same({1,2,3}, nums:take(3))
    assert.same(_.range(1,500), nums:take(500))
    assert.same(_.range(1,501), nums:take(501))
    assert.same(_.range(1,999), nums:take(999))
    assert.same(_.range(1,999), nums:take(1000))

    nums = sc:makeRDD(_.range(1, 999), 100)
    assert.equals(0, #nums:take(0))
    assert.same({1}, nums:take(1))
    assert.same({1,2,3}, nums:take(3))
    assert.same(_.range(1,500), nums:take(500))
    assert.same(_.range(1,501), nums:take(501))
    assert.same(_.range(1,999), nums:take(999))
    assert.same(_.range(1,999), nums:take(1000))

    nums = sc:makeRDD(_.range(1, 999), 1000)
    assert.equals(0, #nums:take(0))
    assert.same({1}, nums:take(1))
    assert.same({1,2,3}, nums:take(3))
    assert.same(_.range(1,500), nums:take(500))
    assert.same(_.range(1,501), nums:take(501))
    assert.same(_.range(1,999), nums:take(999))
    assert.same(_.range(1,999), nums:take(1000))

    nums = sc:parallelize({1,2}, 2)
    assert.equals(2, #nums:take(2147483638))
--    assert.equals(2, nums:takeAsync(2147483638):get())
  end)

--  test("top with predefined ordering") {
--    val nums = Array.range(1, 100000)
--    val ints = sc.makeRDD(scala.util.Random.shuffle(nums), 2)
--    val topK = ints.top(5)
--    assert(topK.size === 5)
--    assert(topK === nums.reverse.take(5))
--  }

--  test("top with custom ordering") {
--    val words = Vector("a", "b", "c", "d")
--    implicit val ord = implicitly[Ordering[String]].reverse
--    val rdd = sc.makeRDD(words, 2)
--    val topK = rdd.top(2)
--    assert(topK.size === 2)
--    assert(topK.sorted === Array("b", "a"))
--  }

--  test("takeOrdered with predefined ordering") {
--    val nums = Array(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)
--    val rdd = sc.makeRDD(nums, 2)
--    val sortedLowerK = rdd.takeOrdered(5)
--    assert(sortedLowerK.size === 5)
--    assert(sortedLowerK === Array(1, 2, 3, 4, 5))
--  }

--  test("takeOrdered with limit 0") {
--    val nums = Array(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)
--    val rdd = sc.makeRDD(nums, 2)
--    val sortedLowerK = rdd.takeOrdered(0)
--    assert(sortedLowerK.size === 0)
--  }

--  test("takeOrdered with custom ordering") {
--    val nums = Array(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)
--    implicit val ord = implicitly[Ordering[Int]].reverse
--    val rdd = sc.makeRDD(nums, 2)
--    val sortedTopK = rdd.takeOrdered(5)
--    assert(sortedTopK.size === 5)
--    assert(sortedTopK === Array(10, 9, 8, 7, 6))
--    assert(sortedTopK === nums.sorted(ord).take(5))
--  }

  it('isEmpty', function()
    assert.is_true(sc:emptyRDD():isEmpty())
    assert.is_true(sc:parallelize({}):isEmpty())
    assert.is_not_true(sc:parallelize({1}):isEmpty())
    assert.is_true(sc:parallelize({1,2,3}, 3):filter(function(x) return x < 0 end):isEmpty())
    assert.is_not_true(sc:parallelize({1,2,3}, 3):filter(function(x) return x > 1 end):isEmpty())
  end)

--  test("sample preserves partitioner") {
--    val partitioner = new HashPartitioner(2)
--    val rdd = sc.parallelize(Seq((0, 1), (2, 3))).partitionBy(partitioner)
--    for (withReplacement <- Seq(true, false)) {
--      val sampled = rdd.sample(withReplacement, 1.0)
--      assert(sampled.partitioner === rdd.partitioner)
--    }
--  }

--  test("takeSample") {
--    val n = 1000000
--    val data = sc.parallelize(1 to n, 2)
--
--    for (num <- List(5, 20, 100)) {
--      val sample = data.takeSample(withReplacement = false, num = num)
--      assert(sample.size === num)        // Got exactly num elements
--      assert(sample.toSet.size === num)  // Elements are distinct
--      assert(sample.forall(x => 1 <= x && x <= n), s"elements not in [1, $n]")
--    }
--    for (seed <- 1 to 5) {
--      val sample = data.takeSample(withReplacement = false, 20, seed)
--      assert(sample.size === 20)        // Got exactly 20 elements
--      assert(sample.toSet.size === 20)  // Elements are distinct
--      assert(sample.forall(x => 1 <= x && x <= n), s"elements not in [1, $n]")
--    }
--    for (seed <- 1 to 5) {
--      val sample = data.takeSample(withReplacement = false, 100, seed)
--      assert(sample.size === 100)        // Got only 100 elements
--      assert(sample.toSet.size === 100)  // Elements are distinct
--      assert(sample.forall(x => 1 <= x && x <= n), s"elements not in [1, $n]")
--    }
--    for (seed <- 1 to 5) {
--      val sample = data.takeSample(withReplacement = true, 20, seed)
--      assert(sample.size === 20)        // Got exactly 20 elements
--      assert(sample.forall(x => 1 <= x && x <= n), s"elements not in [1, $n]")
--    }
--    {
--      val sample = data.takeSample(withReplacement = true, num = 20)
--      assert(sample.size === 20)        // Got exactly 20 elements
--      assert(sample.forall(x => 1 <= x && x <= n), s"elements not in [1, $n]")
--    }
--    {
--      val sample = data.takeSample(withReplacement = true, num = n)
--      assert(sample.size === n)        // Got exactly n elements
--      // Chance of getting all distinct elements is astronomically low, so test we got < n
--      assert(sample.toSet.size < n, "sampling with replacement returned all distinct elements")
--      assert(sample.forall(x => 1 <= x && x <= n), s"elements not in [1, $n]")
--    }
--    for (seed <- 1 to 5) {
--      val sample = data.takeSample(withReplacement = true, n, seed)
--      assert(sample.size === n)        // Got exactly n elements
--      // Chance of getting all distinct elements is astronomically low, so test we got < n
--      assert(sample.toSet.size < n, "sampling with replacement returned all distinct elements")
--    }
--    for (seed <- 1 to 5) {
--      val sample = data.takeSample(withReplacement = true, 2 * n, seed)
--      assert(sample.size === 2 * n)        // Got exactly 2 * n elements
--      // Chance of getting all distinct elements is still quite low, so test we got < n
--      assert(sample.toSet.size < n, "sampling with replacement returned all distinct elements")
--    }
--  }

  it('takeSample from an empty rdd', function()
    local emptySet = sc:parallelize({}, 2)
    local sample = emptySet:takeSample(false, 20, 1)
    assert.equals(0, #sample)
  end)

--  test("randomSplit") {
--    val n = 600
--    val data = sc.parallelize(1 to n, 2)
--    for(seed <- 1 to 5) {
--      val splits = data.randomSplit(Array(1.0, 2.0, 3.0), seed)
--      assert(splits.size == 3, "wrong number of splits")
--      assert(splits.flatMap(_.collect()).sorted.toList == data.collect().toList,
--        "incomplete or wrong split")
--      val s = splits.map(_.count())
--      assert(math.abs(s(0) - 100) < 50) // std =  9.13
--      assert(math.abs(s(1) - 200) < 50) // std = 11.55
--      assert(math.abs(s(2) - 300) < 50) // std = 12.25
--    }
--  }

--  test("runJob on an invalid partition") {
--    intercept[IllegalArgumentException] {
--      sc.runJob(sc.parallelize(1 to 10, 2), {iter: Iterator[Int] => iter.size}, Seq(0, 1, 2))
--    }
--  }

  it('sort an empty RDD', function()
    local data = sc:emptyRDD()
    assert.same({}, data:sortBy(_.identity):collect())
  end)

  it('sortByKey', function()
    local data = sc:parallelize({'5|50|A', '4|60|C', '6|40|B'})

    local col1 = {'4|60|C', '5|50|A', '6|40|B'}
    local col2 = {'6|40|B', '5|50|A', '4|60|C'}
    local col3 = {'5|50|A', '6|40|B', '4|60|C'}

    assert.same(col1, data:sortBy(function(x) return split(x, '|')[1] end):collect())
    assert.same(col2, data:sortBy(function(x) return split(x, '|')[2] end):collect())
    assert.same(col3, data:sortBy(function(x) return split(x, '|')[3] end):collect())
  end)

  it('sortByKey ascending parameter', function()
    local data = sc:parallelize({'5|50|A', '4|60|C', '6|40|B'})

    local asc = {'4|60|C', '5|50|A', '6|40|B'}
    local desc = {'6|40|B', '5|50|A', '4|60|C'}

    assert.same(asc, data:sortBy(function(x) return split(x, '|')[1] end, true):collect())
    assert.same(desc, data:sortBy(function(x) return split(x, '|')[1] end, false):collect())
  end)

--  This test is Scala-specific and not applicable to Lua or other weakly-typed language 
--  test("sortByKey with explicit ordering") {
--  }

--  test("repartitionAndSortWithinPartitions") {
--    val data = sc.parallelize(Seq((0, 5), (3, 8), (2, 6), (0, 8), (3, 8), (1, 3)), 2)
--
--    val partitioner = new Partitioner {
--      def numPartitions: Int = 2
--      def getPartition(key: Any): Int = key.asInstanceOf[Int] % 2
--    }
--
--    val repartitioned = data.repartitionAndSortWithinPartitions(partitioner)
--    val partitions = repartitioned.glom().collect()
--    assert(partitions(0) === Seq((0, 5), (0, 8), (2, 6)))
--    assert(partitions(1) === Seq((1, 3), (3, 8), (3, 8)))
--  }

  it('intersection', function()
    local all = sc:parallelize(_.range(1, 10))
    local evens = sc:parallelize(_.range(2, 10, 2))
    local intersection = {2, 4, 6, 8, 10}

    -- intersection is commutative
    assert.same(intersection, _.sortBy(all:intersection(evens):collect(), _.identity))
    assert.same(intersection, _.sortBy(evens:intersection(all):collect(), _.identity))
  end)

  it('intersection strips duplicates in an input', function()
    local a = sc:parallelize({1, 2, 3, 3})
    local b = sc:parallelize({1, 1, 2, 3})
    local intersection = {1, 2, 3}

    assert.same(intersection, _.sortBy(a:intersection(b):collect(), _.identity))
    assert.same(intersection, _.sortBy(b:intersection(a):collect(), _.identity))
  end)

  it('zipWithIndex', function()
    local n = 10
    local data = sc:parallelize(_.range(0,n), 3)
    local ranked = data:zipWithIndex()
    _.forEach(ranked:collect(), function(x)
      assert.equals(x[2], x[1])
    end)
  end)

  it('zipWithIndex with a single partition', function()
    local n = 10
    local data = sc:parallelize(_.range(0,n), 1)
    local ranked = data:zipWithIndex()
    _.forEach(ranked:collect(), function(x)
      assert.equals(x[2], x[1])
    end)
  end)

  it('zipWithIndex chained with other RDDs (SPARK-4433)', function()
    local count = sc:parallelize(_.range(0,9), 2):zipWithIndex():repartition(4):count() -- Range 0,10 in Scala
    assert.equals(10, count)
  end)

--  test("zipWithUniqueId") {
--    val n = 10
--    val data = sc.parallelize(0 until n, 3)
--    val ranked = data.zipWithUniqueId()
--    val ids = ranked.map(_._1).distinct().collect()
--    assert(ids.length === n)
--  }

--  test("retag with implicit ClassTag") {
--    val jsc: JavaSparkContext = new JavaSparkContext(sc)
--    val jrdd: JavaRDD[String] = jsc.parallelize(Seq("A", "B", "C").asJava)
--    jrdd.rdd.retag.collect()
--  }

--  test("parent method") {
--    val rdd1 = sc.parallelize(1 to 10, 2)
--    val rdd2 = rdd1.filter(_ % 2 == 0)
--    val rdd3 = rdd2.map(_ + 1)
--    val rdd4 = new UnionRDD(sc, List(rdd1, rdd2, rdd3))
--    assert(rdd4.parent(0).isInstanceOf[ParallelCollectionRDD[_]])
--    assert(rdd4.parent[Int](1) === rdd2)
--    assert(rdd4.parent[Int](2) === rdd3)
--  }

--  test("getNarrowAncestors") {
--    val rdd1 = sc.parallelize(1 to 100, 4)
--    val rdd2 = rdd1.filter(_ % 2 == 0).map(_ + 1)
--    val rdd3 = rdd2.map(_ - 1).filter(_ < 50).map(i => (i, i))
--    val rdd4 = rdd3.reduceByKey(_ + _)
--    val rdd5 = rdd4.mapValues(_ + 1).mapValues(_ + 2).mapValues(_ + 3)
--    val ancestors1 = rdd1.getNarrowAncestors
--    val ancestors2 = rdd2.getNarrowAncestors
--    val ancestors3 = rdd3.getNarrowAncestors
--    val ancestors4 = rdd4.getNarrowAncestors
--    val ancestors5 = rdd5.getNarrowAncestors
--
--    // Simple dependency tree with a single branch
--    assert(ancestors1.size === 0)
--    assert(ancestors2.size === 2)
--    assert(ancestors2.count(_ === rdd1) === 1)
--    assert(ancestors2.count(_.isInstanceOf[MapPartitionsRDD[_, _]]) === 1)
--    assert(ancestors3.size === 5)
--    assert(ancestors3.count(_.isInstanceOf[MapPartitionsRDD[_, _]]) === 4)
--
--    // Any ancestors before the shuffle are not considered
--    assert(ancestors4.size === 0)
--    assert(ancestors4.count(_.isInstanceOf[ShuffledRDD[_, _, _]]) === 0)
--    assert(ancestors5.size === 3)
--    assert(ancestors5.count(_.isInstanceOf[ShuffledRDD[_, _, _]]) === 1)
--    assert(ancestors5.count(_ === rdd3) === 0)
--    assert(ancestors5.count(_.isInstanceOf[MapPartitionsRDD[_, _]]) === 2)
--  }

--  test("getNarrowAncestors with multiple parents") {
--    val rdd1 = sc.parallelize(1 to 100, 5)
--    val rdd2 = sc.parallelize(1 to 200, 10).map(_ + 1)
--    val rdd3 = sc.parallelize(1 to 300, 15).filter(_ > 50)
--    val rdd4 = rdd1.map(i => (i, i))
--    val rdd5 = rdd2.map(i => (i, i))
--    val rdd6 = sc.union(rdd1, rdd2)
--    val rdd7 = sc.union(rdd1, rdd2, rdd3)
--    val rdd8 = sc.union(rdd6, rdd7)
--    val rdd9 = rdd4.join(rdd5)
--    val ancestors6 = rdd6.getNarrowAncestors
--    val ancestors7 = rdd7.getNarrowAncestors
--    val ancestors8 = rdd8.getNarrowAncestors
--    val ancestors9 = rdd9.getNarrowAncestors
--
--    // Simple dependency tree with multiple branches
--    assert(ancestors6.size === 3)
--    assert(ancestors6.count(_.isInstanceOf[ParallelCollectionRDD[_]]) === 2)
--    assert(ancestors6.count(_ === rdd2) === 1)
--    assert(ancestors7.size === 5)
--    assert(ancestors7.count(_.isInstanceOf[ParallelCollectionRDD[_]]) === 3)
--    assert(ancestors7.count(_ === rdd2) === 1)
--    assert(ancestors7.count(_ === rdd3) === 1)
--
--    // Dependency tree with duplicate nodes (e.g. rdd1 should not be reported twice)
--    assert(ancestors8.size === 7)
--    assert(ancestors8.count(_ === rdd2) === 1)
--    assert(ancestors8.count(_ === rdd3) === 1)
--    assert(ancestors8.count(_.isInstanceOf[UnionRDD[_]]) === 2)
--    assert(ancestors8.count(_.isInstanceOf[ParallelCollectionRDD[_]]) === 3)
--    assert(ancestors8.count(_ == rdd1) === 1)
--    assert(ancestors8.count(_ == rdd2) === 1)
--    assert(ancestors8.count(_ == rdd3) === 1)
--
--    // Any ancestors before the shuffle are not considered
--    assert(ancestors9.size === 2)
--    assert(ancestors9.count(_.isInstanceOf[CoGroupedRDD[_]]) === 1)
--  }

  --[[
  -- This tests for the pathological condition in which the RDD dependency graph is cyclical.
  --
  -- Since RDD is part of the public API, applications may actually implement RDDs that allow
  -- such graphs to be constructed. In such cases, getNarrowAncestor should not simply hang.
  --]]
--  test("getNarrowAncestors with cycles") {
--    val rdd1 = new CyclicalDependencyRDD[Int]
--    val rdd2 = new CyclicalDependencyRDD[Int]
--    val rdd3 = new CyclicalDependencyRDD[Int]
--    val rdd4 = rdd3.map(_ + 1).filter(_ > 10).map(_ + 2).filter(_ % 5 > 1)
--    val rdd5 = rdd4.map(_ + 2).filter(_ > 20)
--    val rdd6 = sc.union(rdd1, rdd2, rdd3).map(_ + 4).union(rdd5).union(rdd4)
--
--    // Simple cyclical dependency
--    rdd1.addDependency(new OneToOneDependency[Int](rdd2))
--    rdd2.addDependency(new OneToOneDependency[Int](rdd1))
--    val ancestors1 = rdd1.getNarrowAncestors
--    val ancestors2 = rdd2.getNarrowAncestors
--    assert(ancestors1.size === 1)
--    assert(ancestors1.count(_ == rdd2) === 1)
--    assert(ancestors1.count(_ == rdd1) === 0)
--    assert(ancestors2.size === 1)
--    assert(ancestors2.count(_ == rdd1) === 1)
--    assert(ancestors2.count(_ == rdd2) === 0)
--
--    // Cycle involving a longer chain
--    rdd3.addDependency(new OneToOneDependency[Int](rdd4))
--    val ancestors3 = rdd3.getNarrowAncestors
--    val ancestors4 = rdd4.getNarrowAncestors
--    assert(ancestors3.size === 4)
--    assert(ancestors3.count(_.isInstanceOf[MapPartitionsRDD[_, _]]) === 4)
--    assert(ancestors3.count(_ == rdd3) === 0)
--    assert(ancestors4.size === 4)
--    assert(ancestors4.count(_.isInstanceOf[MapPartitionsRDD[_, _]]) === 3)
--    assert(ancestors4.count(_.isInstanceOf[CyclicalDependencyRDD[_]]) === 1)
--    assert(ancestors4.count(_ == rdd3) === 1)
--    assert(ancestors4.count(_ == rdd4) === 0)
--
--    // Cycles that do not involve the root
--    val ancestors5 = rdd5.getNarrowAncestors
--    assert(ancestors5.size === 6)
--    assert(ancestors5.count(_.isInstanceOf[MapPartitionsRDD[_, _]]) === 5)
--    assert(ancestors5.count(_.isInstanceOf[CyclicalDependencyRDD[_]]) === 1)
--    assert(ancestors4.count(_ == rdd3) === 1)
--
--    // Complex cyclical dependency graph (combination of all of the above)
--    val ancestors6 = rdd6.getNarrowAncestors
--    assert(ancestors6.size === 12)
--    assert(ancestors6.count(_.isInstanceOf[UnionRDD[_]]) === 2)
--    assert(ancestors6.count(_.isInstanceOf[MapPartitionsRDD[_, _]]) === 7)
--    assert(ancestors6.count(_.isInstanceOf[CyclicalDependencyRDD[_]]) === 3)
--  }

--  test("task serialization exception should not hang scheduler") {
--    class BadSerializable extends Serializable {
--      @throws(classOf[IOException])
--      private def writeObject(out: ObjectOutputStream): Unit =
--        throw new KryoException("Bad serialization")
--
--      @throws(classOf[IOException])
--      private def readObject(in: ObjectInputStream): Unit = {}
--    }
--    // Note that in the original bug, SPARK-4349, that this verifies, the job would only hang if
--    // there were more threads in the Spark Context than there were number of objects in this
--    // sequence.
--    intercept[Throwable] {
--      sc.parallelize(Seq(new BadSerializable, new BadSerializable)).collect()
--    }
--    // Check that the context has not crashed
--    sc.parallelize(1 to 100).map(x => x*2).collect
--  }

  -- A contrived RDD that allows the manual addition of dependencies after creation.
--  private class CyclicalDependencyRDD[T: ClassTag] extends RDD[T](sc, Nil) {
--    private val mutableDependencies: ArrayBuffer[Dependency[_]] = ArrayBuffer.empty
--    override def compute(p: Partition, c: TaskContext): Iterator[T] = Iterator.empty
--    override def getPartitions: Array[Partition] = Array.empty
--    override def getDependencies: Seq[Dependency[_]] = mutableDependencies
--    def addDependency(dep: Dependency[_]) {
--      mutableDependencies += dep
--    }
--  }

--  test("RDD.partitions() fails fast when partitions indicies are incorrect (SPARK-13021)") {
--    class BadRDD[T: ClassTag](prev: RDD[T]) extends RDD[T](prev) {
--
--      override def compute(part: Partition, context: TaskContext): Iterator[T] = {
--        prev.compute(part, context)
--      }
--
--      override protected def getPartitions: Array[Partition] = {
--        prev.partitions.reverse // breaks contract, which is that `rdd.partitions(i).index == i`
--      }
--    }
--    val rdd = new BadRDD(sc.parallelize(1 to 100, 100))
--    val e = intercept[IllegalArgumentException] {
--      rdd.partitions
--    }
--    assert(e.getMessage.contains("partitions"))
--  }

--  test("nested RDDs are not supported (SPARK-5063)") {
--    val rdd: RDD[Int] = sc.parallelize(1 to 100)
--    val rdd2: RDD[Int] = sc.parallelize(1 to 100)
--    val thrown = intercept[SparkException] {
--      val nestedRDD: RDD[RDD[Int]] = rdd.mapPartitions { x => Seq(rdd2.map(x => x)).iterator }
--      nestedRDD.count()
--    }
--    assert(thrown.getMessage.contains("SPARK-5063"))
--  }

--  test("actions cannot be performed inside of transformations (SPARK-5063)") {
--    val rdd: RDD[Int] = sc.parallelize(1 to 100)
--    val rdd2: RDD[Int] = sc.parallelize(1 to 100)
--    val thrown = intercept[SparkException] {
--      rdd.map(x => x * rdd2.count).collect()
--    }
--    assert(thrown.getMessage.contains("SPARK-5063"))
--  }

--  test("custom RDD coalescer") {
--    val maxSplitSize = 512
--    val outDir = new File(tempDir, "output").getAbsolutePath
--    sc.makeRDD(1 to 1000, 10).saveAsTextFile(outDir)
--    val hadoopRDD =
--      sc.hadoopFile(outDir, classOf[TextInputFormat], classOf[LongWritable], classOf[Text])
--    val coalescedHadoopRDD =
--      hadoopRDD.coalesce(2, partitionCoalescer = Option(new SizeBasedCoalescer(maxSplitSize)))
--    assert(coalescedHadoopRDD.partitions.size <= 10)
--    var totalPartitionCount = 0L
--    coalescedHadoopRDD.partitions.foreach(partition => {
--      var splitSizeSum = 0L
--      partition.asInstanceOf[CoalescedRDDPartition].parents.foreach(partition => {
--        val split = partition.asInstanceOf[HadoopPartition].inputSplit.value.asInstanceOf[FileSplit]
--        splitSizeSum += split.getLength
--        totalPartitionCount += 1
--      })
--      assert(splitSizeSum <= maxSplitSize)
--    })
--    assert(totalPartitionCount == 10)
--  }

--  test("SPARK-18406: race between end-of-task and completion iterator read lock release") {
--    val rdd = sc.parallelize(1 to 1000, 10)
--    rdd.cache()
--
--    rdd.mapPartitions { iter =>
--      ThreadUtils.runInNewThread("TestThread") {
--        // Iterate to the end of the input iterator, to cause the CompletionIterator completion to
--        // fire outside of the task's main thread.
--        while (iter.hasNext) {
--          iter.next()
--        }
--        iter
--      }
--    }.collect()
--  }

  -- NOTE
  -- Below tests calling sc.stop() have to be the last tests in this suite. If there are tests
  -- running after them and if they access sc those tests will fail as sc is already closed, because
  -- sc is shared (this suite mixins SharedSparkContext)
--  test("cannot run actions after SparkContext has been stopped (SPARK-5063)") {
--    val existingRDD = sc.parallelize(1 to 100)
--    sc.stop()
--    val thrown = intercept[IllegalStateException] {
--      existingRDD.count()
--    }
--    assert(thrown.getMessage.contains("shutdown"))
--  }

--  test("cannot call methods on a stopped SparkContext (SPARK-5063)") {
--    sc.stop()
--    def assertFails(block: => Any): Unit = {
--      val thrown = intercept[IllegalStateException] {
--        block
--      }
--      assert(thrown.getMessage.contains("stopped"))
--    }
--    assertFails { sc.parallelize(1 to 100) }
--    assertFails { sc.textFile("/nonexistent-path") }
--  }

  --[[
  -- Coalesces partitions based on their size assuming that the parent RDD is a [HadoopRDD].
  -- Took this class out of the test suite to prevent "Task not serializable" exceptions.
  --]]
--class SizeBasedCoalescer(val maxSize: Int) extends PartitionCoalescer with Serializable {
--  override def coalesce(maxPartitions: Int, parent: RDD[_]): Array[PartitionGroup] = {
--    val partitions: Array[Partition] = parent.asInstanceOf[HadoopRDD[Any, Any]].getPartitions
--    val groups = ArrayBuffer[PartitionGroup]()
--    var currentGroup = new PartitionGroup()
--    var currentSum = 0L
--    var totalSum = 0L
--    var index = 0
--
--    // sort partitions based on the size of the corresponding input splits
--    partitions.sortWith((partition1, partition2) => {
--      val partition1Size = partition1.asInstanceOf[HadoopPartition].inputSplit.value.getLength
--      val partition2Size = partition2.asInstanceOf[HadoopPartition].inputSplit.value.getLength
--      partition1Size < partition2Size
--    })
--
--    def updateGroups(): Unit = {
--      groups += currentGroup
--      currentGroup = new PartitionGroup()
--      currentSum = 0
--    }
--
--    def addPartition(partition: Partition, splitSize: Long): Unit = {
--      currentGroup.partitions += partition
--      currentSum += splitSize
--      totalSum += splitSize
--    }
--
--    while (index < partitions.size) {
--      val partition = partitions(index)
--      val fileSplit =
--        partition.asInstanceOf[HadoopPartition].inputSplit.value.asInstanceOf[FileSplit]
--      val splitSize = fileSplit.getLength
--      if (currentSum + splitSize < maxSize) {
--        addPartition(partition, splitSize)
--        index += 1
--        if (index == partitions.size) {
--          updateGroups
--        }
--      } else {
--        if (currentGroup.partitions.size == 0) {
--          addPartition(partition, splitSize)
--          index += 1
--        } else {
--          updateGroups
--        }
--      }
--    }
--    groups.toArray
--  }
  
end)
