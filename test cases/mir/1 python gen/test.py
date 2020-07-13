"""
       COPYRIGHT (c) 2020 by Featuremine Corporation.
       This software has been provided pursuant to a License Agreement
       containing restrictions on its use.  This software contains
       valuable trade secrets and proprietary information of
       FeatureMine LLC and is protected by law.  It may not be
       copied or distributed in any form or medium, disclosed to third
       parties, reverse engineered or used in any manner not provided
       for in said License Agreement except with the prior written
       authorization from Featuremine Corporation
"""

"""
 @file /test/mir/python-gen/graph-test.py
 @author Vitaut Tryputsin
 @date 24 Jun 2020
"""


# PYTHONPATH=build/lib.linux-x86_64-3.6 python3 ../test/mir/python-gen/_mir_wrapper-test.py
import _mir_wrapper

cp = _mir_wrapper.ConstPoint;
cv = _mir_wrapper.aliases.ConstVector;
assert(cp.x == 1.0 and cp.x == cv.x and cp.y == 2.0 and cp.y == cv.y)

# test enums
assert(_mir_wrapper.utility.TestEnum.val1 == 0 and _mir_wrapper.utility.TestEnum.val3 == 3)
te = _mir_wrapper.utility.EnumStruct(_mir_wrapper.utility.TestEnum.val3)
assert(te.testEnum == 3)
tec = _mir_wrapper.utility.EnumClass()
tec.set_enum(_mir_wrapper.utility.TestEnum.val3)
assert(tec.testEnum == 3)
ret_ec = tec.getHimSelf(tec); 
assert(tec.testEnum == ret_ec.testEnum)

# test method without arguments
p1 = _mir_wrapper.Point(3, 4)
print(p1.x, p1.y)
print("norm: ", p1.norm())
assert(p1.norm() == 5.0)

# test method with single argument
p2 = _mir_wrapper.Point(0, 0)
print("dist: ", p1.dist(p2))
assert(p1.dist(p2) == 5.0)


def test_call(d: float, p1: _mir_wrapper.Point):
    return 1


# test method that return object
util = _mir_wrapper.utility.Utility(test_call)

p3 = util.multiply_points(p1, 3)

assert((p3.x) == 9.0 and (p3.y) == 12.0)

# test method with two simple types
assert(util.divide1(9, 3) == 3.0)

# test method with two simple types
assert(util.multiply1(3, 3) == 9.0)

# test concat strings
assert(util.concat_strings("Hello", " World") == "Hello World")

# test method with simple type
assert(util.add1(3, 5) == 8)

# test method with objects
point4 = util.pointSum(p1, p2)
assert (point4.x == 3.0 and point4.y == 4.0)

# test class without members
class_without_arguments = _mir_wrapper.utility.EmptyClass()
print(class_without_arguments)

# test struct without members
struct_without_arguments = _mir_wrapper.utility.EmptyStruct()

# test struct without members
struct_without_arguments2 = _mir_wrapper.utility.Point()

# test const variable
assert(_mir_wrapper.utility.Pi == 3.14)
assert(_mir_wrapper.utility.HelloWorld == 'Hello World')

# test alias
assert(_mir_wrapper.utility.OrderId(3) == 3)
assert(_mir_wrapper.aliases.Vector(p2))

# test diff types
checker = _mir_wrapper.utility.Checker()
assert (checker.check_int8(127) == 127)
assert (checker.check_int8(128) != 128)
assert (checker.check_int16(32767) == 32767)
assert (checker.check_int32(2147483647) == 2147483647)
assert (checker.check_int64(9223372036854775807) == 9223372036854775807)
assert (checker.check_uint8(255) == 255)
assert (checker.check_uint16(65535) == 65535)
assert (checker.check_uint32(4294967295) == 4294967295)
assert (checker.check_uint64(18446744073709551615) == 18446744073709551615)
assert (checker.check_double(1.79769e+308) == 1.79769e+308)
assert (checker.check_char("h") == "h")
assert (checker.check_bool(True))
assert (checker.check_bool(False) == False)
assert (checker.check_string("hello world") == "hello world")

# test c callback
cb = util.get_callable(p1, 1)
print('cb', cb)
assert(cb(1, p1) == 3)


def call_me(a: float, b: _mir_wrapper.Point) -> int:
    assert(a == 1.0)
    assert(b.x == 3.0)
    assert(b.y == 4.0)
    return 3


assert(util.add_callable(p1, call_me) == 3)

# test send c callback back to c
assert(util.add_callable(p1, cb) == 3)

# test get extra calback
cb2 = util.get_another_callable()
assert(cb2(3.0) == 3)

# test callback with ref
cb3 = util.get_callable_with_ref()
p5 = cb3(3.0)
assert(p5.x == 3.0 and p5.y == 4.0)

# test ref to object in method
p6 = util.get_point_ref()
assert(p6.x == 3.0 and p6.y == 4.0)

# test pointers
swr = _mir_wrapper.aliases.StructWithRef(p6, p6)
assert(swr.ref.x == 3.0 and swr.ref.y == 4.0)
assert(swr.obj.x == 3.0 and swr.obj.y == 4.0)

# test pointers
cwr = _mir_wrapper.aliases.ClassWithRef(p6, p6)
assert(cwr.ref.x == 3.0 and cwr.ref.y == 4.0)
assert(cwr.obj.x == 3.0 and cwr.obj.y == 4.0)

# test alias pointers
als = _mir_wrapper.aliases.AliasStruct(
    _mir_wrapper.aliases.Vector2d(_mir_wrapper.aliases.Vector(p6)),
    _mir_wrapper.aliases.Vector2d(_mir_wrapper.aliases.Vector(p6))
)
print(als.obj.x)
assert(als.obj.x == 3.0 and als.obj.y == 4.0)
assert(als.ref.x == 3.0 and als.ref.y == 4.0)

# test pointers in functions
alsc = _mir_wrapper.aliases.AliasClass(
    _mir_wrapper.aliases.Vector2d(_mir_wrapper.aliases.Vector(p6))
)

assert(alsc.obj.x == 3.0 and alsc.obj.y == 4.0)
assert(alsc.dist(_mir_wrapper.aliases.Vector2d(_mir_wrapper.aliases.Vector(p6))) == 0.0)

# test callable with alias


def point_callback(point: _mir_wrapper.aliases.Vector2d) -> _mir_wrapper.aliases.Vector2d:
    return _mir_wrapper.aliases.Vector2d(_mir_wrapper.aliases.Vector(p6))


p7 = alsc.setCallable(point_callback)
assert(p7.x == 3.0 and p7.y == 4.0)

# test alias as callable
callb = alsc.setAliasCallable(point_callback)
p8 = callb(p7)
assert(p8.x == 3.0 and p8.y == 4.0)

p9 = alsc.aliasCallable(p8)

assert(p9.x == 3.0 and p9.y == 4.0)

# test callback inside callback
mh = _mir_wrapper.utility.pointerHolder()
assert(mh.get_int() == 11)

# test ret nullptr
nt = _mir_wrapper.utility.NoneTester()
print('hello')
assert(nt.get_none() is None)

#test operators

op_pt1 = _mir_wrapper.Point(3, 3)
op_pt2 = _mir_wrapper.Point(1, 1)
op_pt1 += op_pt2

assert(op_pt1.x==4 and op_pt1.y==4  )
op_pt1/=2

assert(op_pt1.x==2 and op_pt1.y==2  )
op_pt1/=0
assert(op_pt1 == None)


int1 = _mir_wrapper.utility.Integer(1)
int2 = _mir_wrapper.utility.Integer(2)
assert(int1<int2)
assert(int1<=int2)
assert(int1<=int1)
assert(int1==int1)
assert(int1!=int2)
assert(not (int1==int2))
assert(not (int1>int2))
assert(int2>=int2)
assert(int2>=int1)
assert(int2>int1)
print('end')
