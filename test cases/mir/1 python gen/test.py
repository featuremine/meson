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
import sys
import psutil
pr = psutil.Process()

def test():
    cp = _mir_wrapper.ConstPoint;
    cv = _mir_wrapper.aliases.ConstVector;
    assert(cp.x == 1.0 and cp.x == cv.x and cp.y == 2.0 and cp.y == cv.y)

    # test enums
    assert(_mir_wrapper.utility.TestEnum.val1.value == 0 and _mir_wrapper.utility.TestEnum.val3.value == 3)
    te = _mir_wrapper.utility.EnumStruct(_mir_wrapper.utility.TestEnum.val3)
    assert str(te)=='test'
    assert(sys.getrefcount(te)==2)
    assert(te.testEnum == _mir_wrapper.utility.TestEnum.val3)
    tec = _mir_wrapper.utility.EnumClass()
    assert(sys.getrefcount(tec)==2)
    tec.set_enum(_mir_wrapper.utility.TestEnum.val3)
    assert(tec.testEnum == _mir_wrapper.utility.TestEnum.val3)
    assert(sys.getrefcount(tec)==2)
    ret_ec = tec.getHimSelf(tec)
    assert(tec==ret_ec)
    print(sys.getrefcount(ret_ec))
    assert(sys.getrefcount(ret_ec)==3)
    assert(tec.testEnum == ret_ec.testEnum)

    # test method without arguments
    p1 = _mir_wrapper.Point(3, 4)
    assert(sys.getrefcount(p1)==2)
    print(p1.x, p1.y)
    print("norm: ", p1.norm())
    assert(p1.norm() == 5.0)
    assert(sys.getrefcount(p1)==2)

    # test method with single argument
    p2 = _mir_wrapper.Point(0, 0)
    print("dist: ", p1.dist(p2))
    assert(p1.dist(p2) == 5.0)
    assert(sys.getrefcount(p2)==2)

    def test_call(d: float, p1: _mir_wrapper.Point):
        return 1


    # test method that return object
    util = _mir_wrapper.utility.Utility(test_call)
    assert(sys.getrefcount(util)==2)

    p3 = util.multiply_points(p1, 3)
    assert(sys.getrefcount(p3)==2)

    assert((p3.x) == 9.0 and (p3.y) == 12.0)

    # test method with two simple types
    assert(util.divide(9, 3) == 3.0)

    # test method with two simple types
    assert(util.multiply(3, 3) == 9.0)

    # test concat strings
    assert(util.concat_strings("Hello", " World") == "Hello World")

    # test method with simple type
    assert(util.add1(3, 5) == 8)

    # test method with objects
    point4 = util.pointSum(p1, p2)
    assert (point4.x == 3.0 and point4.y == 4.0)

    # test class without members
    class_without_arguments = _mir_wrapper.utility.EmptyClass()
    assert(sys.getrefcount(class_without_arguments)==2)

    # test struct without members
    struct_without_arguments = _mir_wrapper.utility.EmptyStruct()
    assert(sys.getrefcount(struct_without_arguments)==2)

    # test struct without members
    struct_without_arguments2 = _mir_wrapper.utility.Point()
    assert(sys.getrefcount(struct_without_arguments2)==2)

    # test const variable
    assert(_mir_wrapper.utility.Pi == 3.14)
    assert(_mir_wrapper.utility.HelloWorld == 'Hello World')
    assert(sys.getrefcount(_mir_wrapper.utility.Pi)==2)

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
    any_test = {}
    assert (checker.check_any(any_test) == any_test)
    # test c callback
    cb = util.get_callable(p1, 1)
    print(cb)
    assert(sys.getrefcount(cb)==2)
    print('cb', cb)
    assert(cb(1, p1) == 3)
    assert(sys.getrefcount(cb)==2)


    def call_me(a: float, b: _mir_wrapper.Point) -> int:
        assert(a == 1.0)
        assert(b.x == 3.0)
        assert(b.y == 4.0)
        return 3

    assert(sys.getrefcount(call_me)==2)
    assert(util.execute_callable(p1, call_me) == 3)
    print(sys.getrefcount(call_me))
    assert(sys.getrefcount(call_me)==2)

    #test send c callback back to c
    assert(util.execute_callable(p1, cb) == 3)


    # test get extra calback
    cb2 = util.get_another_callable()
    assert(sys.getrefcount(cb2)==2)
    assert(cb2(3.0) == 3)

    # test callback with ref
    cb3 = util.get_callable_with_ref()
    p5 = cb3(3.0)
    assert(p5.x == 3.0 and p5.y == 4.0)
    assert(sys.getrefcount(cb3)==2)
    assert(sys.getrefcount(p5)==2)


    # test ref to object in method
    p6 = util.get_point_ref()
    assert(p6.x == 3.0 and p6.y == 4.0)



    # test pointers
    print(sys.getrefcount(p6))
    cwr = _mir_wrapper.aliases.ClassWithRef(p6, p6)
    print(sys.getrefcount(p6))
    assert(cwr.ref.x == 3.0 and cwr.ref.y == 4.0)
    assert(cwr.obj.x == 3.0 and cwr.obj.y == 4.0)

    # test alias pointers
    als = _mir_wrapper.aliases.AliasStruct(
        _mir_wrapper.aliases.Vector2d(_mir_wrapper.aliases.Vector(p6))
    )

    # print(als.obj.x)
    assert(als.obj.x == 3.0 and als.obj.y == 4.0)

    # test pointers in functions
    alsc = _mir_wrapper.aliases.AliasClass(
        _mir_wrapper.aliases.Vector2d(_mir_wrapper.aliases.Vector(p6))
    )

    assert(alsc.obj.x == 3.0 and alsc.obj.y == 4.0)
    assert(alsc.dist(_mir_wrapper.aliases.Vector2d(_mir_wrapper.aliases.Vector(p6))) == 0.0)

    #test callable with alias


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
    assert(nt.get_none() is None)

    # #test operators

    op_pt1 = _mir_wrapper.Point(3, 3)
    op_pt2 = _mir_wrapper.Point(1, 1)
    op_pt1 += op_pt2
 
    assert(op_pt1.x==4 and op_pt1.y==4  )
    op_pt1/=2

    assert(op_pt1.x==2 and op_pt1.y==2  )
    op_pt1/=0
    assert(op_pt1.x == 0, op_pt1.y == 0)


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
    
    #test python type
    testPython = _mir_wrapper.aliases.AliasClass(
                    _mir_wrapper.aliases.Vector2d(
                        _mir_wrapper.aliases.Vector(
                            _mir_wrapper.Point(3, 4))))
    print(sys.getrefcount(testPython))
    pc = _mir_wrapper.utility.PythonTestClass(testPython)
    assert(sys.getrefcount(pc)==2)
    assert(sys.getrefcount(testPython)==3)
    
    def retSelf(obj):
        return obj
    
    testPython2 = pc.test_mthd(testPython)
    assert(sys.getrefcount(testPython2)==4)
    assert(testPython2==testPython)
    print(testPython2.obj.x, testPython2.obj.y)
    assert(testPython2.obj.x==3 and testPython2.obj.y==4)
    ret = pc.execute(testPython,retSelf)
    print(sys.getrefcount(testPython2))

    # struct methods and operators which don't change struct
    d1 = _mir_wrapper.utility.Decimal(1000000000)
    d2 = _mir_wrapper.utility.Decimal(2000000000)

    d3 = d1+d2
    print (d3.value)
    print(d3.to_double())
    assert(d3.to_double() == 3.0)

    assert(d3 == _mir_wrapper.utility.Decimal(3000000000))

    d4 = d1+2000000000
    assert(d4 == 3000000000)

 
    # test set
    py_type_ = testPython
    struct_ = _mir_wrapper.utility.Decimal(1000000000)
    class_ = testPython
    def callable_set():
        pass
    callable_ = callable_set
    int_type_ = 1
    enum_ = _mir_wrapper.utility.TestEnum.val3

    def set_attr(obj, field, var):
        try:
            setattr(obj,field,var)
            return  True
        except:
            return False
    set_class = _mir_wrapper.utility.TestSet(py_type_,struct_,class_,callable_,int_type_,enum_)
    assert (set_attr(set_class, "py_type_", py_type_)==True)
    assert (set_attr(set_class, "py_type_", 1)==False) 
    assert (set_attr(set_class, "struct_", struct_)==True)
    assert (set_attr(set_class, "struct_", 1)==False)     
    assert (set_attr(set_class, "class_", class_)==True)
    assert (set_attr(set_class, "class_", 1)==False) 
    assert (set_attr(set_class, "callable_", callable_)==True)
    assert (set_attr(set_class, "callable_", 1)==False) 
    assert (set_attr(set_class, "int_type_", int_type_)==True)
    assert (set_attr(set_class, "int_type_", "1")==False) 
    assert (set_attr(set_class, "enum_", enum_)==True)
    assert (set_attr(set_class, "enum_", 1)==False) 

    set_struct = _mir_wrapper.utility.TestSetStruct(py_type_,struct_,class_,callable_,int_type_,enum_)
    assert (set_attr(set_struct, "py_type_", py_type_)==True)
    assert (set_attr(set_struct, "py_type_", 1)==False) 
    assert (set_attr(set_struct, "struct_", struct_)==True)
    assert (set_attr(set_struct, "struct_", 1)==False)     
    assert (set_attr(set_struct, "class_", class_)==True)
    assert (set_attr(set_struct, "class_", 1)==False) 
    assert (set_attr(set_struct, "callable_", callable_)==True)
    assert (set_attr(set_struct, "callable_", 1)==False) 
    assert (set_attr(set_struct, "int_type_", int_type_)==True)
    assert (set_attr(set_struct, "int_type_", "1")==False) 
    assert (set_attr(set_struct, "enum_", enum_)==True)
    assert (set_attr(set_struct, "enum_", 1)==False) 

if __name__ == "__main__":
    mem0 = None
    mem10 = None
    mem100 = None

    c = 1000
    start = pr.memory_info().rss
    for i in range(c):
        test()
        if i == 0:
            fd = pr.num_fds()
            mem0 = pr.memory_info().rss
        elif i == 10:
            mem10 = pr.memory_info().rss
        elif i == 100:
            mem100 = pr.memory_info().rss

    print("Memory allocated:", pr.memory_info())
    print(start,mem0,mem10,mem100)
    if mem0:
        percentage_diff = (pr.memory_info().rss - mem0) / mem0 / (c)
        print(percentage_diff)
        assert percentage_diff < 0.0002
    if mem10:
        percentage_diff = (pr.memory_info().rss - mem10) / mem10 / (c - 10)
        print(percentage_diff)
        assert percentage_diff < 0.0002
    if mem100:
        percentage_diff = (pr.memory_info().rss - mem100) / mem100 / (c - 100)
        print(percentage_diff)
        assert percentage_diff < 0.0004
        
print('end')
