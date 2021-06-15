https://dev.mysql.com/doc/refman/5.7/en/sql-mode.html

https://dev.mysql.com/doc/refman/5.7/en/faqs-sql-modes.html

https://dev.mysql.com/doc/refman/5.7/en/innodb-parameters.html#sysvar_innodb_strict_mode

https://dev.mysql.com/doc/refman/5.7/en/data-type-defaults.html

MySQL技术内幕 2.1P65 3.3P163

深入理解MySQL核心技术 P121

1 概述

SQL模式定义了服务器对待SQL语句的方式。

MySQL服务器可以在不同的SQL模式下运行。这些模式影响MySQL支持的SQL语法和执行SQL语句时的行为。例如将引号"作为标识符引用字符还是字符串引用字符、修改记录时如何对待无效数据等。

在MySQL中，SQL模式以系统变量sql-mode提供配置，值是由逗号分隔的不区分大小写的模式列表。作为系统变量，其操作方式也与其他系统变量相同。同时也支持全局和会话两种生效范围。

2 MySQL 5.7中的SQL模式

重要的SQL模式

ANSI

一种组合模式。这种模式改变了语法和行为，使之更接近于标准SQL。

STRICT_TRANS_TABLES

如果一个值不能按照给定的方式插入到一个事务表中，则中止该语句。对于非事务表，如果值出现在单行语句或多行语句的第一行，则中止该语句。严格模式将在下文中详细论述。

TRADITIONAL

一种组合模式。使MySQL表现得像一个 "传统的 "SQL数据库系统。简单地说：当向一列插入不正确的值时，"给出一个错误而不是一个警告"。注意，在启用TRADITIONAL模式时，一旦发生错误，INSERT或UPDATE就会终止。如果使用的是一个非事务性的存储引擎，这可能导致部分更新。

所有SQL模式

ALLOW_INVALID_DATES

不对日期进行全面地检查。只检查月是否在1到12的范围内，日是否在1到31的范围内。这对于在三个不同的字段中分别获取年月日，并且不进行日期验证地准确存储用户插入的内容的Web应用程序可能很有用。这种模式适用于DATE和DATETIME列。但不适用于TIMESTAMP列，因为TIMESTAMP列要求日期值必须有效。

禁用ALLOW_INVALID_DATES后，服务器要求月和日的值是合法的，而不仅仅是在1到12和1到31的范围内。在禁用严格模式的情况下，无效的日期如'2004-04-31'被转换为'0000-00-00'并产生一个警告。在启用严格模式的情况下，无效的日期产生一个错误。

ANSI_QUOTES

将双引号"作为标识符的引用字符（像\`引用字符），而不是作为字符串的引用字符。启用这种模式后，仍然可以使用\`来引用标识符，但不能用双引号来引用字面字符串，因为它们会被解释为标识符。

ERROR_FOR_DIVISION_BY_ZERO

该模式控制对除以0的处理，其中包括MOD(N,0)。对于数据变化操作（INSERT，UPDATE），其影响还取决于是否启用了严格的SQL模式。

如果没有启用严格模式，除以0会插入NULL，并且不产生警告。

如果启用该模式，除以0插入NULL并产生一个警告。

如果启用了这种模式和严格模式，除以0会产生一个错误，除非同时给出IGNORE。对于INSERT IGNORE和UPDATE IGNORE，除以0会插入NULL并产生一个警告。

对于SELECT，除以0会返回NULL。启用ERROR_FOR_DIVISION_BY_ZERO也会产生一个警告，不管严格模式是否被启用。

在MySQL 5.7中，该模式已被弃用。ERROR_FOR_DIVISION_BY_ZERO不是严格模式的一部分，但应该和严格模式一起使用，并且默认为启用。如果启用了ERROR_FOR_DIVISION_BY_ZERO而没有同时启用严格模式，或者反之亦然，则会出现警告。

因为ERROR_FOR_DIVISION_BY_ZERO已被废弃；预计它将在MySQL的未来版本中作为一个单独的模式名称被删除，其效果包括在严格SQL模式的效果中。

HIGH_NOT_PRECEDENCE

NOT运算符的优先级是这样的：诸如NOT a BETWEEN b AND c的表达式被解析为NOT（a BETWEEN b AND c）。在一些旧版本的MySQL中，该表达式被解析为(NOT a) BETWEEN b AND c。可以通过启用该模式以使用旧的较高优先级行为。

```mysql
mysql> SET sql_mode = ''。
mysql> SELECT NOT 1 BETWEEN -5 AND 5;
        -> 0
mysql> SET sql_mode = 'HIGH_NOT_PRECEDENCE';
mysql> SELECT NOT 1 BETWEEN -5 AND 5;
        -> 1
```

IGNORE_SPACE

允许在函数名和括号字符之间有空格。这将导致内置函数名被视为保留字。因此，与函数名相同的标识符必须按照第9.2节 "模式对象名称 "中的描述使用标识符引用字符进行引用。

```mysql
mysql> CREATE TABLE count (i INT);
ERROR 1064 (42000): You have an error in your SQL syntax
The table name should be quoted:

mysql> CREATE TABLE `count` (i INT);
Query OK, 0 rows affected (0.00 sec)
```

IGNORE_SPACE SQL模式仅适用于内置函数，不适用于可加载函数或存储函数。无论IGNORE_SPACE是否被启用，在可加载函数或存储函数名称后面的空格都是被允许的。

关于IGNORE_SPACE的进一步讨论，请参见章节9.2.5, "函数名称解析和解决"。

NO_AUTO_CREATE_USER

防止GRANT语句在未指定认证信息的情况下自动创建新的用户账户。该语句必须使用IDENTIFIED BY指定一个非空的密码，或使用IDENTIFIED WITH指定一个认证插件。

更好的方式是使用用CREATE USER而不是GRANT来创建MySQL账户。

NO_AUTO_CREATE_USER已被废弃，默认SQL模式包括NO_AUTO_CREATE_USER。对sql_mode的赋值如果改变了NO_AUTO_CREATE_USER模式的状态，会产生一个警告，除非将sql_mode设置为DEFAULT的赋值。预计NO_AUTO_CREATE_USER在未来的MySQL版本中被删除，并且其效果在任何时候都被启用，以及GRANT语句将不再创建账户。

以前，在NO_AUTO_CREATE_USER被废弃之前，不启用它的一个原因是它不具有复制安全性。现在它可以被启用，并通过CREATE USER IF NOT EXISTS、DROP USER IF EXISTS和ALTER USER IF EXISTS而不是GRANT来进行复制安全的用户管理。当副本的授权与源的授权不同时，这些语句可以实现安全复制。参见第13.7.1.2节 "CREATE USER语句"，第13.7.1.3节 "DROP USER语句"，和第13.7.1.1节 "ALTER USER语句"。

NO_AUTO_VALUE_ON_ZERO

该模式影响对AUTO_INCREMENT列的处理。通常情况下，你通过插入NULL或0来为该列生成下一个序列号。NO_AUTO_VALUE_ON_ZERO禁止了指定值为0的这种行为，因此只有插入NULL才能生成下一个序列号。

如果0被存储在表的AUTO_INCREMENT列中，这种模式可能是有用的。(顺便说一下，存储0不是一种推荐的做法。)例如，如果用mysqldump转储表，然后重新加载它，MySQL通常在遇到0值时生成新的序列号，导致表的内容与转储的内容不同。在重新加载转储文件之前启用NO_AUTO_VALUE_ON_ZERO可以解决这个问题。由于这个原因，mysqldump在其输出中自动包括一个启用NO_AUTO_VALUE_ON_ZERO的语句。

NO_BACKSLASH_ESCAPES

启用此模式后，反斜杠字符（\）不能作为字符串和标识符中的转义字符使用。启用该模式后，反斜线变成了一个与其他字符一样的普通字符，LIKE表达式的默认转义序列被改变，因此没有转义字符能被使用。

NO_DIR_IN_CREATE

当创建一个表时，忽略所有INDEX DIRECTORY和DATA DIRECTORY指令。这个选项在复制的务器上很有用。

NO_ENGINE_SUBSTITUTION

当诸如CREATE TABLE或ALTER TABLE这样的语句指定了一个禁用或未编译的存储引擎时，该模式控制默认存储引擎的自动替换。

默认情况下，NO_ENGINE_SUBSTITUTION被启用。

因为存储引擎在运行时可以被插入，所以不可用的引擎也被同样对待：

在禁用NO_ENGINE_SUBSTITUTION的情况下，如果所需的引擎不可用，对于CREATE TABLE，会使用默认的引擎，会有一个警告。对于ALTER TABLE，会出现一个警告，并且表不会被改变。

在启用NO_ENGINE_SUBSTITUTION的情况下，如果所需的引擎不可用，就会发生错误，表不会被创建或修改。

NO_FIELD_OPTIONS

不在SHOW CREATE TABLE的输出中打印MySQL特定的列选项。这种模式被mysqldump在可移植性模式下使用。

注意
从MySQL 5.7.22开始，NO_FIELD_OPTIONS被弃用。它在MySQL 8.0中被删除。

NO_KEY_OPTIONS

不在SHOW CREATE TABLE的输出中打印MySQL特定的索引选项。这种模式被mysqldump在可移植性模式下使用。

注意
从MySQL 5.7.22开始，NO_KEY_OPTIONS被弃用。它在MySQL 8.0中被删除。

NO_TABLE_OPTIONS

不在SHOW CREATE TABLE的输出中打印MySQL特定的表选项（如ENGINE）。该模式由mysqldump在可移植性模式下使用。

注意
从MySQL 5.7.22开始，NO_TABLE_OPTIONS被弃用。它在MySQL 8.0中被删除。

NO_UNSIGNED_SUBTRACTION

在整数值之间做减法，其中一个是UNSIGNED类型，默认产生一个无符号的结果。如果结果是负数，会产生一个错误。

```mysql
mysql> SET sql_mode = '';
Query OK, 0 rows affected (0.00 sec)

mysql> SELECT CAST(0 AS UNSIGNED) - 1;
ERROR 1690 (22003): BIGINT UNSIGNED value is out of range in '(cast(0 as unsigned) - 1)'
```

如果启用了NO_UNSIGNED_SUBTRACTION模式，结果是负的。

```mysql
mysql> SET sql_mode = 'NO_UNSIGNED_SUBTRACTION';
mysql> SELECT CAST(0 AS UNSIGNED) - 1;
+-------------------------+
| CAST(0 AS UNSIGNED) - 1 |
+-------------------------+
|                      -1 |
+-------------------------+
```

如果这种操作的结果被用来更新一个UNSIGNED整数列，那么结果会被剪切到该列类型的最大值，如果启用了NO_UNSIGNED_SUBTRACTION，则剪切到0。在启用严格模式时，会发生错误，并且列保持不变。

当启用NO_UNSIGNED_SUBTRACTION时，减去的结果是有符号的，即使任何操作数是无符号的。例如，比较表t1中列c2的类型和表t2中列c2的类型。

```mysql
mysql> SET sql_mode='';
mysql> CREATE TABLE test (c1 BIGINT UNSIGNED NOT NULL);
mysql> CREATE TABLE t1 SELECT c1 - 1 AS c2 FROM test;
mysql> DESCRIBE t1;
+-------+---------------------+------+-----+---------+-------+
| Field | Type                | Null | Key | Default | Extra |
+-------+---------------------+------+-----+---------+-------+
| c2    | bigint(21) unsigned | NO   |     | 0       |       |
+-------+---------------------+------+-----+---------+-------+

mysql> SET sql_mode='NO_UNSIGNED_SUBTRACTION';
mysql> CREATE TABLE t2 SELECT c1 - 1 AS c2 FROM test;
mysql> DESCRIBE t2;
+-------+------------+------+-----+---------+-------+
| Field | Type       | Null | Key | Default | Extra |
+-------+------------+------+-----+---------+-------+
| c2    | bigint(21) | NO   |     | 0       |       |
+-------+------------+------+-----+---------+-------+
```

这意味着BIGINT UNSIGNED不是在所有情况下都可用的。参见第12.11节，"Cast函数和操作符"。

NO_ZERO_DATE

NO_ZERO_DATE模式影响服务器是否允许 "0000-00-00 "作为一个有效的日期。它的效果也取决于是否启用了严格的SQL模式。

如果没有启用这个模式，'0000-00-00'是被允许的，并且插入时不会产生警告。

如果这个模式被启用，'0000-00-00'被允许，并且插入会产生警告。

如果启用了这种模式和严格模式，'0000-00-00'是不允许的，插入会产生一个错误，除非同时给出IGNORE。对于INSERT IGNORE和UPDATE IGNORE，'0000-00-00'是允许的，插入会产生一个警告。

NO_ZERO_DATE已被废弃。NO_ZERO_DATE不是严格模式的一部分，但是应该和严格模式一起使用，并且默认为启用。如果在启用NO_ZERO_DATE的同时没有启用严格模式，则会出现警告，反之亦然。有关其他讨论，请参阅MySQL 5.7中的SQL模式变化。

因为NO_ZERO_DATE已被废弃；预计它将在未来的MySQL版本中作为一个单独的模式名称被删除，其效果包括在严格SQL模式的效果中。

NO_ZERO_IN_DATE

NO_ZERO_IN_DATE模式影响服务器是否允许年部分为非零但月或日部分为0的日期。（这个模式影响诸如'2010-00-01'或'2010-01-00'这样的日期，但不影响'0000-00-00'。要控制服务器是否允许'0000-00-00'，请使用NO_ZERO_DATE模式）。) NO_ZERO_IN_DATE的效果也取决于是否启用了严格的SQL模式。

如果没有启用这个模式，允许有零部分的日期，插入时不会产生警告。

如果这个模式被启用，带有零部分的日期被插入为'0000-00-00'并产生一个警告。

如果这个模式和严格模式被启用，则不允许有零部分的日期，并且插入产生一个错误，除非 IGNORE 也被给出。对于INSERT IGNORE和UPDATE IGNORE，有零部分的日期被插入为'0000-00-00'并产生一个警告。

NO_ZERO_IN_DATE已经被废弃。NO_ZERO_IN_DATE不是严格模式的一部分，但是应该和严格模式一起使用，并且默认为启用。如果在启用NO_ZERO_IN_DATE的同时没有启用严格模式，或者相反，会出现警告。有关其他讨论，请参阅MySQL 5.7中的SQL模式变化。

因为NO_ZERO_IN_DATE已被废弃；预计它将在未来的MySQL版本中作为一个单独的模式名称被删除，其效果包括在严格SQL模式的效果中。

ONLY_FULL_GROUP_BY

Reject queries for which the select list, HAVING condition, or ORDER BY list refer to nonaggregated columns that are neither named in the GROUP BY clause nor are functionally dependent on (uniquely determined by) GROUP BY columns.

As of MySQL 5.7.5, the default SQL mode includes ONLY_FULL_GROUP_BY. (Before 5.7.5, MySQL does not detect functional dependency and ONLY_FULL_GROUP_BY is not enabled by default. For a description of pre-5.7.5 behavior, see the MySQL 5.6 Reference Manual.)

A MySQL extension to standard SQL permits references in the HAVING clause to aliased expressions in the select list. Before MySQL 5.7.5, enabling ONLY_FULL_GROUP_BY disables this extension, thus requiring the HAVING clause to be written using unaliased expressions. As of MySQL 5.7.5, this restriction is lifted so that the HAVING clause can refer to aliases regardless of whether ONLY_FULL_GROUP_BY is enabled.

For additional discussion and examples, see Section 12.20.3, “MySQL Handling of GROUP BY”.

拒绝select列表、HAVING条件或ORDER BY列表引用非分组列的查询，这些列既没有在GROUP BY子句中命名，也没有在功能上依赖于（由GROUP BY列唯一决定）。

从MySQL 5.7.5开始，默认SQL模式包括ONLY_FULL_GROUP_BY。(在5.7.5之前，MySQL不检测功能依赖性，ONLY_FULL_GROUP_BY默认不启用。关于5.7.5之前的行为描述，见《MySQL 5.6参考手册》）。)

MySQL对标准SQL的一个扩展允许在HAVING子句中引用选择列表中的别名表达式。在MySQL 5.7.5之前，启用ONLY_FULL_GROUP_BY可禁用该扩展，因此需要使用无别名表达式来编写HAVING子句。从MySQL 5.7.5开始，这个限制被解除了，因此无论ONLY_FULL_GROUP_BY是否被启用，HAVING子句都可以引用别字。

有关其他讨论和例子，请参见第12.20.3节 "MySQL对GROUP BY的处理"。

PAD_CHAR_TO_FULL_LENGTH

默认情况下，在检索时，CHAR列值的尾部空格会被修剪。如果启用了PAD_CHAR_TO_FULL_LENGTH，则不会进行修剪，检索到的CHAR值会被填充到其全长。这种模式不适用于VARCHAR列，因为VARCHAR列在检索时保留尾部空格。

```mysql
mysql> CREATE TABLE t1 (c1 CHAR(10));
Query OK, 0 rows affected (0.37 sec)

mysql> INSERT INTO t1 (c1) VALUES('xy');
Query OK, 1 row affected (0.01 sec)

mysql> SET sql_mode = '';
Query OK, 0 rows affected (0.00 sec)

mysql> SELECT c1, CHAR_LENGTH(c1) FROM t1;
+------+-----------------+
| c1   | CHAR_LENGTH(c1) |
+------+-----------------+
| xy   |               2 |
+------+-----------------+
1 row in set (0.00 sec)

mysql> SET sql_mode = 'PAD_CHAR_TO_FULL_LENGTH';
Query OK, 0 rows affected (0.00 sec)

mysql> SELECT c1, CHAR_LENGTH(c1) FROM t1;
+------------+-----------------+
| c1         | CHAR_LENGTH(c1) |
+------------+-----------------+
| xy         |              10 |
+------------+-----------------+
1 row in set (0.00 sec)
```

PIPES_AS_CONCAT

将||作为字符串连接操作符（与CONCAT()相同），而不是作为OR的同义词。

REAL_AS_FLOAT

将REAL视为FLOAT的同义词。默认情况下，MySQL将REAL视为DOUBLE的同义词。

STRICT_ALL_TABLES

为所有存储引擎启用严格的SQL模式。无效的数据值会被拒绝。详情请参见严格的SQL模式。

从MySQL 5.7.4到5.7.7，STRICT_ALL_TABLES包括ERROR_FOR_DIVISION_BY_ZERO、NO_ZERO_DATE和NO_ZERO_IN_DATE模式的效果。有关其他讨论，请参阅MySQL 5.7中的SQL模式变化。

STRICT_TRANS_TABLES

为事务性存储引擎启用严格的SQL模式，并在可能时为非事务性存储引擎启用严格的SQL模式。详情请参见严格的SQL模式。

从MySQL 5.7.4到5.7.7，STRICT_TRANS_TABLES包括ERROR_FOR_DIVISION_BY_ZERO、NO_ZERO_DATE和NO_ZERO_IN_DATE模式的效果。有关其他讨论，请参阅MySQL 5.7中的SQL模式变化。

组合SQL模式

组合模式是作为模式值的组合的速记。

ANSI

相当于REAL_AS_FLOAT、PIPES_AS_CONCAT、ANSI_QUOTES、IGNORE_SPACE和（从MySQL 5.7.5开始）ONLY_FULL_GROUP_BY。

ANSI模式还导致服务器在查询中返回一个错误，即具有外部引用S(outer_ref)的集合函数S不能在外部引用被解决的外部查询中被聚合。这就是这样一个查询。

SELECT * FROM t1 WHERE t1.a IN (SELECT MAX(t1.b) FROM t2 WHERE ...) 。
这里，MAX(t1.b)不能在外层查询中聚合，因为它出现在该查询的WHERE子句中。在这种情况下，标准SQL需要一个错误。如果没有启用ANSI模式，服务器对这种查询中的S(outer_ref)的处理方式与对S(const)的解释相同。

参见第1.7节，"MySQL标准遵从"。

DB2

相当于PIPES_AS_CONCAT, ANSI_QUOTES, IGNORE_SPACE, NO_KEY_OPTIONS, NO_TABLE_OPTIONS, NO_FIELD_OPTIONS。

注意事项
从MySQL 5.7.22开始，DB2被弃用。它在MySQL 8.0中被删除。

MAXDB

相当于PIPES_AS_CONCAT, ANSI_QUOTES, IGNORE_SPACE, NO_KEY_OPTIONS, NO_TABLE_OPTIONS, NO_FIELD_OPTIONS, NO_AUTO_CREATE_USER。

注意事项
从MySQL 5.7.22开始，MAXDB被弃用。它在MySQL 8.0中被删除。

MSSQL

相当于PIPES_AS_CONCAT, ANSI_QUOTES, IGNORE_SPACE, NO_KEY_OPTIONS, NO_TABLE_OPTIONS, NO_FIELD_OPTIONS。

注意事项
从MySQL 5.7.22开始，MSSQL被弃用。它将在MySQL 8.0中被删除。

MYSQL323

等同于MYSQL323，HIGH_NOT_PRECEDENCE。这意味着HIGH_NOT_PRECEDENCE加上一些特定于MYSQL323的SHOW CREATE TABLE行为。

TIMESTAMP列的显示不包括DEFAULT或ON UPDATE属性。

字符串列的显示不包括字符集和排序属性。对于CHAR和VARCHAR列，如果整理方式是二进制，那么BINARY将被附加到列的类型上。

ENGINE=engine_name表选项显示为TYPE=engine_name。

对于MEMORY表，存储引擎被显示为HEAP。

注意
从MySQL 5.7.22开始，MYSQL323被弃用。它将在MySQL 8.0中被删除。

MYSQL40

等同于MYSQL40，HIGH_NOT_PRECEDENCE。这意味着HIGH_NOT_PRECEDENCE加上MYSQL40的一些特定行为。这些与MYSQL323相同，除了SHOW CREATE TABLE不显示HEAP作为MEMORY表的存储引擎。

注意
从MySQL 5.7.22开始，MYSQL40已被废弃。它将在MySQL 8.0中被删除。

ORACLE

相当于PIPES_AS_CONCAT, ANSI_QUOTES, IGNORE_SPACE, NO_KEY_OPTIONS, NO_TABLE_OPTIONS, NO_FIELD_OPTIONS, NO_AUTO_CREATE_USER。

注意事项
从MySQL 5.7.22开始，ORACLE被弃用。它在MySQL 8.0中被删除。

POSTGRESQL

相当于PIPES_AS_CONCAT, ANSI_QUOTES, IGNORE_SPACE, NO_KEY_OPTIONS, NO_TABLE_OPTIONS, NO_FIELD_OPTIONS。

注意事项
从MySQL 5.7.22开始，POSTGRESQL被弃用。它将在MySQL 8.0中被删除。

TRADITIONAL

在MySQL 5.7.4之前，以及在MySQL 5.7.8及以后，TRADITIONAL等同于STRICT_TRANS_TABLES、STRICT_ALL_TABLES、NO_ZERO_IN_DATE、NO_ZERO_DATE、ERROR_FOR_DIVISION_BY_ZERO、NO_AUTO_CREATE_USER、NO_ENGINE_SUBSTITUTION。

从MySQL 5.7.4到5.7.7，TRADITIONAL相当于STRICT_TRANS_TABLES、STRICT_ALL_TABLES、NO_AUTO_CREATE_USER和NO_ENGINE_SUBSTITUTION。NO_ZERO_IN_DATE、NO_ZERO_DATE和ERROR_FOR_DIVISION_BY_ZERO模式没有被命名，因为在这些版本中，它们的效果包括在严格SQL模式（STRICT_ALL_TABLES或STRICT_TRANS_TABLES）的效果中。因此，TRADITIONAL的效果在所有MySQL 5.7版本中都是一样的（与MySQL 5.6版本相同）。有关其他讨论，请参阅MySQL 5.7中的SQL模式变化。

3 严格模式：

SQL模式定义了服务器对待客户端输入的方式。其中，严格模式用于控制MySQL如何处理数据变更语句（如INSERT或UPDATE）中的无效或缺失值。严格模式也影响到DDL语句，例如CREATE TABLE。

一个值可能因为几个原因而无效。例如，它可能与列定义的数据类型不同，或者它可能超出了范围。若一个列定义为NOT NULL且没有明确的DEFAULT子句，当要插入的新行不包含一个该列的值时，则发生缺失。

对于无效或缺失值，总是可以有两种做法：

​	产生错误，不再继续执行命令

​	尝试对其进行适当地调整，如果调整失败，则产生错误并停止执行；若调整成功，则继续执行命令，并在执行结束后产生警告

严格模式的开启和关闭就分别对应这两种处理方式。

默认情况下，MySQL会按照以下规则处理非正常值。

​	对于数值列或TIME列，超出合法取值范围的那些值将被截断到取值范围最近的那个端点，并把结果值存储起来。
​	对于除TIME以外的其他时态类型列，非法值会被转换成与该类型相一致的“零”值(见表3.15)
​	对于字符串列(不包括ENUM或SET)，过长的字符串将被截断到该列的最大长度。

​	给ENUM或SET类型列进行赋值时，需要根据列定义里给出的合法取值列表进行。如果把不是枚举成员的值赋给ENUM列，那么列的值会变成“出错”成员(即与零值成员相对应的空字符串)。如果把包含非集合成员的子字符串的值赋给SET列，那么这些字符串会被清理，剩余的成员才会被赋值给列。

ignore关键字

严格模式的作用在于将警告提升为错误，而IGNORE关键字则可以将错误降为警告。可以通过使用INSERT IGNORE或UPDATE IGNORE产生这种行为。当IGNORE关键字和严格模式同时生效时，IGNORE优先。这意味着，尽管IGNORE和严格模式可以被认为对错误处理有相反的效果，但它们在一起使用时并不抵消。

| Operational Mode                    | When Statement Default is Error                     | When Statement Default is Warning                     |
| :---------------------------------- | :-------------------------------------------------- | :---------------------------------------------------- |
| Without `IGNORE` or strict SQL mode | Error                                               | Warning                                               |
| With `IGNORE`                       | Warning                                             | Warning (same as without `IGNORE` or strict SQL mode) |
| With strict SQL mode                | Error (same as without `IGNORE` or strict SQL mode) | Error                                                 |
| With `IGNORE` and strict SQL mode   | Warning                                             | Warning                                               |

MySQL 5.7中的严格模式

影响范围

对于像SELECT这样不改变数据的语句，无效的值在严格模式下产生警告，而不是错误。

严格模式对试图创建超过最大索引长度的索引的行为产生错误。当严格模式未被启用时，这将导致警告并将密钥截断到最大密钥长度。

严格模式不影响是否检查外键约束，外键检查可用于此。参见章节5.1.7, "服务器系统变量"）。

使用

STRICT_ALL_TABLES或者STRICT_TRANS_TABLES都表示严格模式就会生效，尽管它们的效果有些不同。

对于事务表，当STRICT_ALL_TABLES或STRICT_TRANS_TABLES被启用时，在数据变化语句中的无效值或缺失值会发生错误。语句被中止并回滚。

对于非事务表，如果坏值发生在要插入或更新的第一行中，两种模式的行为都是一样的。语句被中止，表保持不变。如果语句插入或修改了多条记录，并且坏值发生在第二条或以后的记录中，其结果取决于哪种严格模式被启用。

对于STRICT_ALL_TABLES，MySQL返回一个错误并忽略其余的行。然而，由于早期的行已经被插入或更新，结果是部分更新。为了避免这种情况，使用单行语句，它可以被中止而不改变表。

对于STRICT_TRANS_TABLES，MySQL将一个无效的值转换为该列最接近的有效值，并插入调整后的值。如果缺少一个值，MySQL插入该列数据类型的隐含默认值。在这两种情况下，MySQL都会产生一个警告而不是一个错误，并继续处理该语句。隐式默认值在第11.6节 "数据类型默认值 "中描述。

根据上述行为可以得出，STRICT_ALL_TABLES表示对所有类型的表，都严厉地执行严格模式，不管错误出现在哪里，都返回该错误。STRICT_TRANS_TABLES则是在满足事务原子性的前提下执行严格模式，因此对于非事务表，当错误发生在第一行中，则可以返回错误，此时没有语句被执行，即不会出现部分修改情况；但当错误发生在第一行之后，由于非事务表不能回滚，因此为了避免出现部分修改，采取了调整继续执行并产生警告的方式而非返回错误。

例

```mysql
mysql> CREATE TABLE no_trans_table (id int(11) NOT NULL AUTO_INCREMENT, content varchar(64) NOT NULL, PRIMARY KEY (id)) ENGINE = MyISAM CHARSET = utf8mb4;
Query OK, 0 rows affected (0.01 sec)

mysql> select * from no_trans_table;
Empty set (0.00 sec)

mysql> SET @@sql_mode = 'STRICT_ALL_TABLES';
Query OK, 0 rows affected, 2 warnings (0.00 sec)

mysql> show warnings;
*************************** 1. row ***************************
  Level: Warning
   Code: 3135
Message: 'NO_ZERO_DATE', 'NO_ZERO_IN_DATE' and 'ERROR_FOR_DIVISION_BY_ZERO' sql modes should be used with strict mode. They will be merged with strict mode in a future release.
*************************** 2. row ***************************
  Level: Warning
   Code: 3090
Message: Changing sql mode 'NO_AUTO_CREATE_USER' is deprecated. It will be removed in a future release.
2 rows in set (0.00 sec)

mysql> INSERT INTO no_trans_table (content) VALUES (NULL),('1');
ERROR 1048 (23000): Column 'content' cannot be null
mysql> select * from no_trans_table;
Empty set (0.00 sec)

mysql> INSERT INTO no_trans_table (content) VALUES ('2'), (NULL);
ERROR 1048 (23000): Column 'content' cannot be null
mysql> select * from no_trans_table;
*************************** 1. row ***************************
     id: 1
content: 2
1 row in set (0.00 sec)

mysql> SET @@sql_mode = 'STRICT_TRANS_TABLES';
Query OK, 0 rows affected, 1 warning (0.00 sec)

mysql> show warnings;
*************************** 1. row ***************************
  Level: Warning
   Code: 3135
Message: 'NO_ZERO_DATE', 'NO_ZERO_IN_DATE' and 'ERROR_FOR_DIVISION_BY_ZERO' sql modes should be used with strict mode. They will be merged with strict mode in a future release.
1 row in set (0.00 sec)

mysql> INSERT INTO no_trans_table (content) VALUES (NULL),('3');
ERROR 1048 (23000): Column 'content' cannot be null
mysql> select * from no_trans_table;
*************************** 1. row ***************************
     id: 1
content: 2
1 row in set (0.01 sec)

mysql> INSERT INTO no_trans_table (content) VALUES ('4'), (NULL);
Query OK, 2 rows affected, 1 warning (0.00 sec)
Records: 2  Duplicates: 0  Warnings: 1

mysql> show warnings;
*************************** 1. row ***************************
  Level: Warning
   Code: 1048
Message: Column 'content' cannot be null
1 row in set (0.00 sec)

mysql> select * from no_trans_table;
*************************** 1. row ***************************
     id: 1
content: 2
*************************** 2. row ***************************
     id: 2
content: 4
*************************** 3. row ***************************
     id: 3
content:
3 rows in set (0.00 sec)

```

对0值的处理

严格模式对除以0、零日期和日期中的零的处理有如下影响。

严格模式影响对除以0的处理，包括MOD(N,0)。

对于数据变化操作（INSERT, UPDATE）。

如果没有启用严格模式，除以0会插入NULL，并且不产生警告。

如果启用了严格模式，除以0会产生一个错误，除非同时给出IGNORE。对于INSERT IGNORE和UPDATE IGNORE，除以0会插入NULL并产生警告。

对于SELECT，除以0会返回NULL。启用严格模式也会产生一个警告。

严格模式影响服务器是否允许 "0000-00-00 "作为一个有效的日期。

如果不启用严格模式，'0000-00-00'是被允许的，插入时不会产生警告。

如果严格模式被启用，'0000-00-00'是不允许的，插入会产生一个错误，除非IGNORE也被给出。对于INSERT IGNORE和UPDATE IGNORE，'0000-00-00'是允许的，插入会产生一个警告。

严格模式影响服务器是否允许年部分为非零但月或日部分为0的日期（如'2010-00-01'或'2010-01-00'）。

如果不启用严格模式，允许零部分的日期，插入时不产生警告。

如果严格模式被启用，不允许有零部分的日期，并且插入产生一个错误，除非IGNORE也被给出。对于INSERT IGNORE和UPDATE IGNORE，有零部分的日期被插入为'0000-00-00'（这被认为是有效的IGNORE）并产生一个警告。

关于IGNORE的严格模式的更多信息，见IGNORE关键字和严格SQL模式的比较。

在MySQL 5.7.4之前，以及在MySQL 5.7.8及更高版本中，严格模式会影响对除以0、零日期和日期中的零的处理，与ERROR_FOR_DIVISION_BY_ZERO、NO_ZERO_DATE和NO_ZERO_IN_DATE模式一起。从MySQL 5.7.4到5.7.7，ERROR_FOR_DIVISION_BY_ZERO、NO_ZERO_DATE和NO_ZERO_IN_DATE模式在明确命名时不做任何事情，其效果包括在严格模式的效果中。有关其他讨论，请参阅MySQL 5.7中的SQL模式变化。

InnoDB中的严格模式

在处理InnoDB表时，也要考虑innodb_strict_mode系统变量，它控制对InnoDB表进行额外的错误检查的行为。



4 扩展：sqlmode与分区表

Important

**SQL mode and user-defined partitioning.** Changing the server SQL mode after creating and inserting data into partitioned tables can cause major changes in the behavior of such tables, and could lead to loss or corruption of data. It is strongly recommended that you never change the SQL mode once you have created tables employing user-defined partitioning.

When replicating partitioned tables, differing SQL modes on the source and replica can also lead to problems. For best results, you should always use the same server SQL mode on the source and replica.

For more information, see [Section 22.6, “Restrictions and Limitations on Partitioning”](https://dev.mysql.com/doc/refman/5.7/en/partitioning-limitations.html).

代码中很多地方都受本选项的影响。为了了解其工作需要做的一些事情是:
检查sql/mysqld.cc中的sql_mode_names变量定义。查看sql/set_varcc中的fix_sq1_mode()。
在sql/sql_yacc.yy、sql/sql_show.cc、sql/sql_parse.cc和sql/sql_lex.cc中查找 sql_mode。

Strict_error_handler::handle_condition