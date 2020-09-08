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
    def double_callable(d):
        return 1
    t = _mir_wrapper.Test()
    t.double_callable(double_callable)


    
    
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
