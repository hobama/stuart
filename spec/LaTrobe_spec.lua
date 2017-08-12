local _ = require 'lodash'
local inspect = require 'inspect'
local registerAsserts = require 'registerAsserts'
local stuart = require 'stuart'

registerAsserts(assert)

-- http://homepage.cs.latrobe.edu.au/zhe/ZhenHeSparkRDDAPIExamples.html
describe('La Trobe University Spark 1.4 Examples', function()

  local sc = stuart.NewContext()
  
  it('aggregate() Examples 1', function()
    local z = sc:parallelize({1,2,3,4,5,6}, 2)
    local seqOp = function(x,y) return math.max(x,y) end
    local combOp = function(x,y) return x+y end
    local actual = z:aggregate(0, seqOp, combOp)
    assert.equals(9, actual)
  end)
  
  it('cartesian()', function()
    local x = sc:parallelize({1,2,3,4,5})
    local y = sc:parallelize({6,7,8,9,10})
    local actual = x:cartesian(y):collect()
    assert.contains_pair(actual, {1,6})
    assert.contains_pair(actual, {1,7})
    assert.contains_pair(actual, {1,8})
    assert.contains_pair(actual, {1,9})
    assert.contains_pair(actual, {1,10})
    assert.contains_pair(actual, {2,6})
    assert.contains_pair(actual, {2,7})
    assert.contains_pair(actual, {2,8})
    assert.contains_pair(actual, {2,9})
    assert.contains_pair(actual, {2,10})
    assert.contains_pair(actual, {3,6})
    assert.contains_pair(actual, {3,7})
    assert.contains_pair(actual, {3,8})
    assert.contains_pair(actual, {3,9})
    assert.contains_pair(actual, {3,10})
    assert.contains_pair(actual, {4,6})
    assert.contains_pair(actual, {4,7})
    assert.contains_pair(actual, {4,8})
    assert.contains_pair(actual, {4,9})
    assert.contains_pair(actual, {4,10})
    assert.contains_pair(actual, {5,6})
    assert.contains_pair(actual, {5,7})
    assert.contains_pair(actual, {5,8})
    assert.contains_pair(actual, {5,9})
    assert.contains_pair(actual, {5,10})
  end)

  it('count()', function()
    local c = sc:parallelize({'Gnu', 'Cat', 'Rat', 'Dog'})
    assert.equals(4, c:count())
  end)

  it('countByKey()', function()
    local c = sc:parallelize({{3,'Gnu'}, {3,'Yak'}, {5,'Mouse'}, {3,'Dog'}})
    local actual = c:countByKey()
    assert.equals(3, actual[3])
    assert.equals(1, actual[5])
  end)

  it('countByValue()', function()
    local b = sc:parallelize({1,2,3,4,5,6,7,8,2,4,2,1,1,1,1,1})
    local actual = b:countByValue()
    assert.equals(1, actual[5])
    assert.equals(1, actual[8])
    assert.equals(1, actual[3])
    assert.equals(1, actual[8])
    assert.equals(1, actual[6])
    assert.equals(6, actual[1])
    assert.equals(3, actual[2])
    assert.equals(2, actual[4])
    assert.equals(1, actual[7])
  end)

  it('distinct()', function()
    local c = sc:parallelize({'Gnu', 'Cat', 'Rat', 'Dog', 'Gnu', 'Rat'})
    local actual = c:distinct():collect()
    assert.equals(4, #actual)
  end)

  it('filter() without mixed data', function()
    local a = sc:parallelize({1,2,3,4,5,6,7,8,9,10}, 3)
    local b = a:filter(function(x) return x % 2 == 0 end)
    local actual = b:collect()
    assert.same({2,4,6,8,10}, actual)
  end)

  it('filter() with mixed data', function()
    local b = sc:parallelize(_.range(1,8))
    local actual = b:filter(function(x) return x < 4 end):collect()
    assert.same({1,2,3}, actual)
    
    local a = sc:parallelize({'cat', 'horse', 4.0, 3.5, 2, 'dog'})
    assert.has_error(function()
      a:filter(function(x) return x < 4 end):collect()
    end)
  end)

  it('first()', function()
    local c = sc:parallelize({'Gnu', 'Cat', 'Rat', 'Dog'})
    assert.equals('Gnu', c:first())
  end)

  it('flatMap()', function()
    local a = sc:parallelize({1,2,3,4,5,6,7,8,9,10}, 5)
    local actual = a:flatMap(function(x) return _.range(1,x) end):collect()
    local expected = {1, 1, 2, 1, 2, 3, 1, 2, 3, 4, 1, 2, 3, 4, 5, 1, 2, 3, 4, 5, 6, 1, 2, 3, 4, 5, 6, 7, 1, 2, 3, 4, 5, 6, 7, 8, 1, 2, 3, 4, 5, 6, 7, 8, 9, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10}
    assert.same(expected, actual)
    
    actual = sc:parallelize({1,2,3}, 2):flatMap(function(x) return {x,x,x} end):collect()
    expected = {1, 1, 1, 2, 2, 2, 3, 3, 3}
    assert.same(expected, actual)
  end)

  it('flatMapValues()', function()
    local a = sc:parallelize({'dog', 'tiger', 'lion', 'cat', 'panther', 'eagle'}, 2)
    local b = a:map(function(x) return {string.len(x), x} end)
    local actual = b:flatMapValues(function(x) return 'x' .. x .. 'x' end):collect()
    local expected = {
      {3,'x'}, {3,'d'}, {3,'o'}, {3,'g'}, {3,'x'}, {5,'x'}, {5,'t'}, {5,'i'},
      {5,'g'}, {5,'e'}, {5,'r'}, {5,'x'}, {4,'x'}, {4,'l'}, {4,'i'}, {4,'o'},
      {4,'n'}, {4,'x'}, {3,'x'}, {3,'c'}, {3,'a'}, {3,'t'}, {3,'x'}, {7,'x'},
      {7,'p'}, {7,'a'}, {7,'n'}, {7,'t'}, {7,'h'}, {7,'e'}, {7,'r'}, {7,'x'},
      {5,'x'}, {5,'e'}, {5,'a'}, {5,'g'}, {5,'l'}, {5,'e'}, {5,'x'}
    }
    assert.same(expected, actual)
  end)

  it('fold()', function()
    local a = sc:parallelize({1, 2, 3}, 3)
    local actual = a:fold(0, function(a,b) return a+b end)
    assert.equals(6, actual)
  end)

  it('foldByKey()', function()
    local a = sc:parallelize({'dog', 'cat', 'owl', 'gnu', 'ant'}, 2)
    local b = a:map(function(x) return {string.len(x), x} end)
    local actual = b:foldByKey('', function(a,b) return a .. b end):collect()
    assert.same({{3,'dogcatowlgnuant'}}, actual)
  end)

  it('foreach()', function()
    local c = sc:parallelize({'cat', 'dog', 'tiger', 'lion', 'gnu', 'crocodile', 'ant', 'whale', 'dolphin', 'spider'}, 3)
    local r = {}
    c:foreach(function(x) table.insert(r, x .. 's are yummy') end)
    local expected = {
      'cats are yummy',
      'dogs are yummy',
      'tigers are yummy',
      'lions are yummy',
      'gnus are yummy',
      'crocodiles are yummy',
      'ants are yummy',
      'whales are yummy',
      'dolphins are yummy',
      'spiders are yummy',
    }
    assert.same(expected, r)
  end)

  it('foreachPartition()', function()
    local b = sc:parallelize({1,2,3,4,5,6,7,8,9}, 3)
    local actual = {}
    b:foreachPartition(function(x)
      local v = _.reduce(x, function(r,a) return r+a end, 0)
      table.insert(actual, v)
    end)
    assert.same({6,15,24}, actual)
  end)

  it('groupBy()', function()
    local a = sc:parallelize(_.range(1,9), 3)
    local actual = a:groupBy(function(x)
      if x % 2 == 0 then return 'even' else return 'odd' end
    end):collect()
    assert.contains_keyed_pair(actual, 'even', {2,4,6,8})
    assert.contains_keyed_pair(actual, 'odd', {1,3,5,7,9})
  end)

  it('groupByKey()', function()
    local a = sc:parallelize({'dog', 'tiger', 'lion', 'cat', 'spider', 'eagle'}, 2)
    local b = a:keyBy(function(x) return string.len(x) end)
    assert.same({{3,'dog'}, {5,'tiger'}, {4,'lion'}, {3,'cat'}, {6,'spider'}, {5,'eagle'}}, b:collect(), 'pre-condition sanity check')
    local actual = b:groupByKey():collect()
    assert.contains_keyed_pair(actual, 4, {'lion'})
    assert.contains_keyed_pair(actual, 6, {'spider'})
    assert.contains_keyed_pair(actual, 3, {'dog','cat'})
    assert.contains_keyed_pair(actual, 5, {'tiger','eagle'})
  end)

  it('histogram() with even spacing', function()
    local a = sc:parallelize({1.1, 1.2, 1.3, 2.0, 2.1, 7.4, 7.5, 7.6, 8.8, 9.0}, 3)
    local buckets, counts = a:histogram(5)
    assert.same({1.1, 2.68, 4.26, 5.84, 7.42, 9.0}, buckets)
    assert.same({5, 0, 0, 1, 4}, counts)
    
    a = sc:parallelize({9.1, 1.0, 1.2, 2.1, 1.3, 5.0, 2.0, 2.1, 7.4, 7.5, 7.6, 8.8, 10.0, 8.9, 5.5}, 3)
    buckets, counts = a:histogram(6)
    assert.same({1.0, 2.5, 4.0, 5.5, 7.0, 8.5, 10.0}, buckets)
    assert.same({6, 0, 1, 1, 3, 4}, counts)
  end)

  it('histogram() with custom spacing', function()
    local a = sc:parallelize({1.1, 1.2, 1.3, 2.0, 2.1, 7.4, 7.5, 7.6, 8.8, 9.0}, 3)
    local counts = a:histogram({0.0, 3.0, 8.0})
    assert.same({5, 3}, counts)
    
    a = sc:parallelize({9.1, 1.0, 1.2, 2.1, 1.3, 5.0, 2.0, 2.1, 7.4, 7.5, 7.6, 8.8, 10.0, 8.9, 5.5}, 3)
    counts = a:histogram({0.0, 5.0, 10.0})
    assert.same({6, 9}, counts)
    
    counts = a:histogram({0.0, 5.0, 10.0, 15.0})
    assert.same({6, 8, 1}, counts)
  end)

  it('intersection()', function()
    local x = sc:parallelize(_.range(1,20))
    local y = sc:parallelize(_.range(10,30))
    local z = x:intersection(y)
    local actual = z:collect() 
    local expected = {16, 12, 20, 13, 17, 14, 18, 10, 19, 15, 11}
    table.sort(actual)
    table.sort(expected)
    assert.same(expected, actual)
  end)

  it('join()', function()
    local a = sc:parallelize({'dog', 'salmon', 'salmon', 'rat', 'elephant'}, 3)
    local b = a:keyBy(function(x) return string.len(x) end)
    local c = sc:parallelize({'dog', 'cat', 'gnu', 'salmon', 'rabbit', 'turkey', 'wolf', 'bear', 'bee'}, 3)
    local d = c:keyBy(function(x) return string.len(x) end)
    local actual = b:join(d):collect()
    assert.contains_keyed_pair(actual, 6, {'salmon', 'salmon'})
    assert.contains_keyed_pair(actual, 6, {'salmon', 'rabbit'})
    assert.contains_keyed_pair(actual, 6, {'salmon', 'turkey'})
    assert.contains_keyed_pair(actual, 3, {'dog', 'dog'})
    assert.contains_keyed_pair(actual, 3, {'dog', 'cat'})
    assert.contains_keyed_pair(actual, 3, {'dog', 'gnu'})
    assert.contains_keyed_pair(actual, 3, {'dog', 'bee'})
    assert.contains_keyed_pair(actual, 3, {'rat', 'dog'})
    assert.contains_keyed_pair(actual, 3, {'rat', 'cat'})
    assert.contains_keyed_pair(actual, 3, {'rat', 'gnu'})
    assert.contains_keyed_pair(actual, 3, {'rat', 'bee'})
  end)

  it('keyBy()', function()
    local a = sc:parallelize({'dog', 'salmon', 'salmon', 'rat', 'elephant'})
    local b = a:keyBy(function(x) return string.len(x) end)
    local actual = b:collect()
    local expected = {
      {3,'dog'},
      {6,'salmon'},
      {6,'salmon'},
      {3,'rat'},
      {8,'elephant'}
    } 
    assert.same(expected, actual)
  end)

  it('keys()', function()
    local a = sc:parallelize({'dog', 'tiger', 'lion', 'cat', 'panther', 'eagle'}, 2)
    local b = a:map(function(x) return {string.len(x), x} end)
    local actual = b:keys():collect()
    local expected = {3,5,4,3,7,5}
    assert.same(expected, actual)
  end)

  it('leftOuterJoin()', function()
    local a = sc:parallelize({'dog', 'salmon', 'salmon', 'rat', 'elephant'}, 3)
    local b = a:keyBy(function(x) return string.len(x) end)
    local c = sc:parallelize({'dog', 'cat', 'gnu', 'salmon', 'rabbit', 'turkey', 'wolf', 'bear', 'bee'}, 3)
    local d = c:keyBy(function(x) return string.len(x) end)
    local actual = b:leftOuterJoin(d):collect()
    assert.contains_keyed_pair(actual, 6, {'salmon', 'salmon'})
    assert.contains_keyed_pair(actual, 6, {'salmon', 'rabbit'})
    assert.contains_keyed_pair(actual, 6, {'salmon', 'turkey'})
    assert.contains_keyed_pair(actual, 3, {'dog', 'dog'})
    assert.contains_keyed_pair(actual, 3, {'dog', 'cat'})
    assert.contains_keyed_pair(actual, 3, {'dog', 'gnu'})
    assert.contains_keyed_pair(actual, 3, {'dog', 'bee'})
    assert.contains_keyed_pair(actual, 3, {'rat', 'dog'})
    assert.contains_keyed_pair(actual, 3, {'rat', 'cat'})
    assert.contains_keyed_pair(actual, 3, {'rat', 'gnu'})
    assert.contains_keyed_pair(actual, 3, {'rat', 'bee'})
    assert.contains_keyed_pair(actual, 8, {'elephant', nil})
  end)

  it('lookup()', function()
    local a = sc:parallelize({'dog', 'tiger', 'lion', 'cat', 'panther', 'eagle'}, 2)
    local b = a:map(function(x) return {string.len(x), x} end)
    local actual = b:lookup(5)
    assert.contains(actual, 'tiger')
    assert.contains(actual, 'eagle')
  end)

  it('map()', function()
    local a = sc:parallelize({'dog', 'salmon', 'salmon', 'rat', 'elephant'}, 3)
    local b = a:map(function(x) return string.len(x) end)
    local c = a:zip(b)
    local actual = c:collect()
    assert.contains_pair(actual, {'dog',3})
    assert.contains_pair(actual, {'salmon',6})
    assert.contains_pair(actual, {'rat',3})
    assert.contains_pair(actual, {'elephant',8})
  end)

  it('mapValues()', function()
    local a = sc:parallelize({'dog', 'tiger', 'lion', 'cat', 'panther', 'eagle'})
    local b = a:map(function(x) return {string.len(x), x} end)
    local actual = b:mapValues(function(x) return 'x' .. x .. 'x' end):collect() 
    local expected = {
      {3, 'xdogx'},
      {5, 'xtigerx'},
      {4, 'xlionx'},
      {3, 'xcatx'},
      {7, 'xpantherx'},
      {5, 'xeaglex'}
    }
    assert.same(expected, actual)
  end)

  it('max()', function()
    local y = sc:parallelize(_.range(10,30))
    assert.equals(30, y:max())
  end)

  it('min()', function()
    local y = sc:parallelize(_.range(10,30))
    assert.equals(10, y:min())
  end)

  it('partitions()', function()
    local b = sc:parallelize({'gnu', 'cat', 'rat', 'dog', 'gnu', 'rat'}, 2)
    local partitions = b:partitions()
    assert.is_table(partitions)
    assert.equals(2, _.size(partitions))
  end)

  it('reduce()', function()
    local a = sc:parallelize(_.range(1,100), 3)
    local actual = a:reduce(function(r,x) return r+x end)
    assert.equals(5050, actual)
    
    a = sc:parallelize({'dog', 'tiger', 'lion', 'cat', 'panther', 'eagle'})
    b = a:map(function(x) return {string.len(x), x} end)
    actual = b:reduceByKey(function(r, x) return r .. x end):collect()
    assert.contains_keyed_pair(actual, 4, 'lion')
    assert.contains_keyed_pair(actual, 3, 'dogcat')
    assert.contains_keyed_pair(actual, 7, 'panther')
    assert.contains_keyed_pair(actual, 5, 'tigereagle')
  end)

  it('reduceByKey()', function()
    local a = sc:parallelize({'dog', 'cat', 'owl', 'gnu', 'ant'})
    local b = a:map(function(x) return {string.len(x), x} end)
    local actual = b:reduceByKey(function(r,x) return r .. x end):collect() 
    local expected = {{3,'dogcatowlgnuant'}}
    assert.same(expected, actual)
    
    a = sc:parallelize({'dog', 'tiger', 'lion', 'cat', 'panther', 'eagle'})
    b = a:map(function(x) return {string.len(x), x} end)
    actual = b:reduceByKey(function(r, x) return r .. x end):collect()
    assert.contains_keyed_pair(actual, 4, 'lion')
    assert.contains_keyed_pair(actual, 3, 'dogcat')
    assert.contains_keyed_pair(actual, 7, 'panther')
    assert.contains_keyed_pair(actual, 5, 'tigereagle')
  end)

  it('repartition()', function()
    local rdd = sc:parallelize({1,2,10,4,5,2,1,1,1}, 3)
    assert.equals(3, #rdd:partitions())
    local rdd2 = rdd:repartition(5)
    assert.equals(5, #rdd2:partitions())
  end)

  it('stats()', function()
    local x = sc:parallelize({1.0, 2.0, 3.0, 5.0, 20.0, 19.02, 19.29, 11.09, 21.0}, 2)
    local stats = x:stats() 
    assert.equals(9, stats.count)
    assert.is_in_range(stats.mean, 11.26, 11.27)
    assert.is_in_range(stats.stdev, 8, 9)
  end)

  it('subtract()', function()
    local a = sc:parallelize(_.range(1,9), 3)
    local b = sc:parallelize(_.range(1,3), 3)
    local c = a:subtract(b)
    local actual = c:collect()
    assert.not_contains(actual, 1)
    assert.not_contains(actual, 2)
    assert.not_contains(actual, 3)
    assert.contains(actual, 4)
    assert.contains(actual, 5)
    assert.contains(actual, 6)
    assert.contains(actual, 7)
    assert.contains(actual, 8)
    assert.contains(actual, 9)
  end)

  it('subtractByKey()', function()
    local a = sc:parallelize({'dog', 'tiger', 'lion', 'cat', 'spider', 'eagle'}, 2)
    local b = a:keyBy(function(x) return string.len(x) end)
    local c = sc:parallelize({'ant', 'falcon', 'squid'}, 2)
    local d = c:keyBy(function(x) return string.len(x) end)
    local result = b:subtractByKey(d):collect()
    assert.contains_pair(result, {4,'lion'})
  end)
  
  it('take()', function()
    local b = sc:parallelize({'dog', 'cat', 'ape', 'salmon', 'gnu'}, 2)
    local actual = b:take(2)
    assert.same({'dog', 'cat'}, actual)
    
    b = sc:parallelize(_.range(1,10000), 5000)
    actual = b:take(100)
    expected = {
      1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,
      21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,
      41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,
      61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,
      81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100
    }
    assert.same(expected, actual)
  end)

  it('toLocalIterator()', function()
    local z = sc:parallelize({1,2,3,4,5,6}, 2)
    local iter = z:toLocalIterator()
    local actual = {}
    for e in iter do
      table.insert(actual, e)
    end
    assert.contains(actual, 1)
    assert.contains(actual, 2)
  end)

  it('union()', function()
    local a = sc:parallelize(_.range(1,3), 1)
    local b = sc:parallelize(_.range(5,7), 1)
    local actual = a:union(b):collect() 
    assert.same({1,2,3,5,6,7}, actual)
  end)

  it('values()', function()
    local a = sc:parallelize({'dog', 'tiger', 'lion', 'cat', 'panther', 'eagle'}, 2)
    local b = a:map(function(x) return {string.len(x), x} end)
    local actual = b:values():collect() 
    assert.same({'dog', 'tiger', 'lion', 'cat', 'panther', 'eagle'}, actual)
  end)

  it('zip()', function()
    local a = sc:parallelize(_.range(1,100), 3)
    local b = sc:parallelize(_.range(101,200), 3)
    local actual = a:zip(b):collect() 
    assert.contains_pair(actual, {1,101})
    assert.contains_pair(actual, {2,102})
    assert.contains_pair(actual, {99,199})
    assert.contains_pair(actual, {100,200})
  end)

end)