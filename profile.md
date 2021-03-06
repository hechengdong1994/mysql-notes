原则一：性能即响应时间（完成某件任务所需要的时间度量）

原则二：无法测量就无法有效地优化（所以第一步应该测量时间花在什么地方）

大多数系统无法完整地测量，测量有时也会有错误的结果。但也可以想办法绕过一些限制，并得到好的结果（但要能意识到所使用的方法的缺陷和不确定性在哪）

有两种消耗时间的操作：工作/等待。大多数剖析器只能测量因为工作而消耗的时间，所以等待分析有时候是很有用的补充，尤其是当CPU利用率很低但工作却一直无法完成的时候。

合适的测量范围是指只测量需要优化的活动。

性能剖析profiling是测量和分析时间花费在哪里的主要方法。一般有两个步骤：测量任务所花费的时间，然后对结果进行统计和排序，将重要的任务排在前面。

