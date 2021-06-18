mysql技术内幕第五版 P451 12.8 服务器日志

mysql技术内幕：innodb存储引擎 P48 3.2日志文件

mysql排错指南 P97 2.8.5 日志文件 P162 慢查询日志 P173 错误与日志

1 简介

日志可以帮助找到正在发生的活动。根据记录内容的不同，有多种不同类型的日志。

| Log Type               | Information Written to Log                                   |
| :--------------------- | :----------------------------------------------------------- |
| Error log              | Problems encountered starting, running, or stopping [**mysqld**](https://dev.mysql.com/doc/refman/5.7/en/mysqld.html) |
| General query log      | Established client connections and statements received from clients |
| Binary log             | Statements that change data (also used for replication)      |
| Relay log              | Data changes received from a replication source server       |
| Slow query log         | Queries that took more than [`long_query_time`](https://dev.mysql.com/doc/refman/5.7/en/server-system-variables.html#sysvar_long_query_time) seconds to execute |
| DDL log (metadata log) | Metadata operations performed by DDL statements              |

2 通用查询日志

2.1 记录内容和写入时机

通用查询日志是mysqld正在做什么的一般记录。当客户机连接或断开连接时，以及从客户机收到的每个SQL语句，服务器都会将信息写入此日志。

显示客户机连接时的每一行包括使用connection_type来表示用于建立连接的协议。connection_type是TCP/IP(建立的TCP/IP连接没有SSL)、SSL/TLS(建立的TCP/IP连接有SSL)、Socket(Unix socket文件连接)、Named Pipe(Windows命名管道连接)或Shared Memory(Windows共享内存连接)之一。

mysqld按照接收语句的顺序将其写入查询日志，这可能与语句的执行顺序不同。此外，查询日志可能只包含select语句，而这样的语句永远不会写到二进制日志中。

当在复制源服务器上使用基于语句的二进制日志时，其副本收到的语句被写到每个副本的查询日志。如果客户端用mysqlbinlog工具读取事件并将其传递给服务器，则语句会被写入源的查询日志。

然而，当使用基于行的二进制日志时，更新作为行变化而不是SQL语句被发送，因此，当binlog_format为ROW时，这些语句永远不会被写入查询日志。当这个变量被设置为MIXED时，一个给定的更新也可能不会被写到查询日志中，这取决于所使用的语句。更多信息请参见章节16.2.1.1, "基于语句和基于行的复制的优缺点"。

具体写入时机：当设置启用general_log时（包括以general_log=ON启动或在运行过程中从OFF设置为ON），服务器就会打开相应的日志文件，并写入启动信息。对于sql语句记录，**结合词法分析和语法分析，应该是在词法分析通过后写入**

2.2 相关配置

log_output：全局范围，用于指定通用查询日志和慢查询日志的输出目的地。它的值是一个由逗号分隔的枚举值组成的列表，值从TABLE（记录到表）、FILE（记录到文件）或NONE（不记录到表或文件）中选择。其中NONE优先于任何其他指定符。默认值是FILE。如果指定了TABLE，请参阅日志表和 "太多开放文件 "错误。

general_log：全局范围，控制是否启用通用查询日志。默认禁用。配置方式为[general_log[={0|1}]]。可不指定值或指定值为1来启用该配置。

sql_log_off：局部/全局范围。控制当前会话是否将sql语句记录到通用查询日志中。即在会话中，sql_log_off的优先级高于general_log。**但在客户端连接时，会根据general_log变量来记录一条连接（Connect）信息（疑问：因为此时会话还未生成？通过源码解答，涉及到连接处理中的变量处理和general_log、sql_log_off处理逻辑）；**后续通过该连接发送的命令，根据sql_log_off控制是否进行记录（包括exit退出命令）。即，在general_log=1且global.sql_log_off=1的情况下，通用查询日志中仅会记录客户端连接信息。

general_log_file：全局范围，用于指定通用查询日志文件的文件名。默认值是host_name.log。表示在数据目录下创建该文件，该参数还可以指定一个绝对路径名来指定不同的目录。每次设置该参数时，如果一个日志文件已经打开，它将被关闭，新的文件被打开。

2.3 查询重写

服务器在记录通用查询日志、慢查询日志、二进制日志时，默认会记录由查询重写插件返回的语句，这可能与收到的原始语句不同。通过使用--log-raw选项启动服务器，可以抑制该重写行为。这个选项对于诊断来说可能很有用，可以看到服务器收到的语句的确切文本，但是出于安全原因，不建议在生产中使用。

一个重写的例子是语句中的密码部分，不会以纯文本的形式出现。参见第6.1.2.3节，"密码和日志"。密码重写的一个含义是，不能被解析的语句（例如，由于语法错误）不会被写入通用查询日志，因为它们不能被知道是无密码的。需要记录所有语句（包括有错误的语句）的用例应该使用--log-raw选项，记住这也绕过了密码重写。

密码重写只发生在有纯文本密码的情况下。

```mysql
#指定纯文本密码，general_log会发生重写
CREATE USER 'user1'@'localhost' IDENTIFIED BY 'not-so-secret';
```

对于语法上有密码哈希值的语句，不会发生重写。如果在这种语法中错误地提供了纯文本密码，密码会被记录下来，而不进行重写。例如，下面的语句被记录为所示，因为预期有一个密码哈希值。

```mysql
mysql> CREATE USER 'user1'@'localhost' IDENTIFIED BY PASSWORD 'not-so-secret';
ERROR 1827 (HY000): The password hash doesn't have the expected format. Check if the correct password algorithm is being used with the PASSWORD() function.
```

log_timestamps系统变量控制写入一般查询日志文件（以及慢速查询日志文件和错误日志）的消息中的时间戳的时区。它不影响写到日志表中的一般查询日志和慢速查询日志信息的时区，但是从这些表中检索的行可以通过CONVERT_TZ()或设置会话时间区系统变量从本地系统时区转换为任何需要的时区。

2.4 运维操作

服务器重启和日志刷新不会导致生成一个新的通用查询日志文件（尽管刷新会关闭并重新打开它）。要重命名该文件并创建一个新的文件，请使用以下命令。

```shell
shell> mv host_name.log host_name-old.log
shell> mysqladmin flush-logs
shell> mv host_name-old.log backup-directory
```

你也可以在运行时通过禁用日志来重命名一般查询日志文件。

```mysql
SET GLOBAL general_log = 'OFF';
```

在禁用日志的情况下，从外部重命名日志文件（例如，从命令行）。然后再次启用该日志。

```mysql
SET GLOBAL general_log = 'ON';
```

这个方法可以在任何平台上使用，不需要重新启动服务器。



3 慢查询日志

3.1 记录内容和写入时机

慢速查询日志由执行时间超过long_query_time毫秒（最小值和默认值分别为0和10）且至少需要检查min_examined_row_limit行的SQL语句组成。然而，检查一个长的慢速查询日志可能是一个耗时的任务。为了使之更容易，你可以使用mysqldumpslow命令来处理一个慢速查询日志文件并总结其内容。见第4.6.8节，"mysqldumpslow--总结慢速查询日志文件"。

获取初始锁的时间不计入执行时间。mysqld在语句被执行和所有锁被释放后将其写入慢速查询日志，所以日志顺序可能与执行顺序不同。

当设置启用slow_query_log时（包括以slow_query_log=ON启动或在运行过程中从OFF设置为ON），服务器就会打开相应的日志文件，并写入启动信息。（启动时的行为与通用查询日志相同）

3.2 相关配置

log_output：与通用查询日志相同

slow_query_log、slow_query_log_file：类比通用查询日志。慢速查询日志文件默认名称是host_name-slow.log。

--log-short-format：启动项。如果使用该选项，服务器写到慢查询日志的信息就会减少。

long_query_time：慢查询语句的最低执行时间。单位秒，最小值和默认值分别为0和10，该值可以被指定为微秒的分辨率。毫秒这个值是以实时测量的，而不是CPU时间，所以在轻度负载的系统上低于阈值的查询可能在重度负载的系统上高于阈值。

min_examined_row_limit：检查少于这个行数的查询不会被记录到慢速查询日志。最小值和默认值都为0

log_slow_admin_statements：控制管理语句是否需要被记录，默认不记录。管理语句包括ALTER TABLE, ANALYZE TABLE, CHECK TABLE, CREATE INDEX, DROP INDEX, OPTIMIZE TABLE和REPAIR TABLE。

log_queries_not_using_indexes：不使用索引查找的查询是否需要被记录。默认不记录。即使启用了这个变量，服务器也不会记录那些由于表少于两行而无法从索引的存在中受益的查询。

log_throttle_queries_not_using_indexes：当不使用索引的查询被记录时，慢速查询日志可能会迅速增长。可以对这些查询进行速率限制。默认情况下，这个变量是0，这意味着没有限制。正值对不使用索引的查询的记录施加每分钟的限制。第一个这样的查询会打开一个60秒的窗口，在这个窗口中，服务器会记录到给定限制的查询，然后抑制其他的查询。如果在窗口结束时还有被抑制的查询，服务器会记录一个摘要，指出有多少查询以及在这些查询中花费的总时间。下一个60秒窗口从服务器记录下一个不使用索引的查询时开始。

log_slow_slave_statements：默认情况下，一个副本不会将复制的查询写入慢查询日志。要改变这一点，请启用该变量。注意，如果使用了基于行的复制（binlog_format=ROW），该变量不会生效。只有当查询在二进制日志中以语句格式记录时，即binlog_format=STATEMENT，或者binlog_format=MIXED且语句以语句格式记录时，才会被添加到副本的慢查询日志中。当binlog_format=MIXED或ROW时，以行格式记录的慢查询不会被添加到副本的慢查询日志，即使log_slow_slave_statements被启用。

2.3 写入逻辑

服务器按照以下顺序使用控制参数来决定是否将一个查询写入慢查询日志。

**对查询缓存处理的查询和来自源服务的查询是否写入的判断时机？通过源码解释**

服务器不记录由查询缓存处理的查询。

该查询必须不是一个管理语句，或者必须启用log_slow_admin_statements。

查询必须至少花了long_query_time秒，或者必须启用log_queries_not_using_indexes，并且查询没有使用索引进行行查找。

该查询必须至少检查了min_examined_row_limit行。

根据log_throttle_queries_not_using_indexes的设置，该查询必须没有被抑制。

3.4 慢查询日志包含内容
如果启用了慢查询日志，并选择FILE作为输出目的地，则写入日志的每条语句前面都有一行以#字符开始，并有这些字段（所有字段在一行）。

Query_time: duration。语句的执行时间，单位是秒。

Lock_time: 持续时间。获得锁的时间，以秒计。

Rows_sent: N。发送给客户端的行数。

Rows_examined: 服务器层检查的行数（不计入存储引擎内部的任何处理）。

每个写入慢速查询日志文件的语句前面都有一个SET语句，其中包括一个时间戳，表明慢语句被记录的时间（发生在语句执行完毕之后）。

3.5 查询重写

参考通用查询日志。

4 日志表

通用查询日志和慢查询日志可以指定使用日志表进行记录。

使用表格进行日志输出有以下好处。

日志条目有一个标准的格式。可以通过下列语句查看日志表的当前结构：

```mysql
SHOW CREATE TABLE mysql.general_log;
SHOW CREATE TABLE mysql.slow_log;
```

日志内容可以通过SQL语句访问。这样就可以使用select查询来选择那些满足特定条件的日志条目。例如，要选择与特定客户端相关的日志内容（这对于识别来自该客户端的有问题的查询很有用），使用日志表比使用日志文件更容易做到这一点。

日志可以通过任何可以连接到服务器并发出查询的客户端进行远程访问（如果该客户端有适当的日志表权限）。没有必要登录到服务器主机并直接访问文件系统。

日志表的实现有以下特点。

一般来说，日志表的主要目的是为用户提供一个观察服务器运行时执行情况的接口，而不是干扰其运行时执行。

CREATE TABLE、ALTER TABLE和DROP TABLE是对一个日志表的有效操作。对于ALTER TABLE和DROP TABLE，日志表无法继续被使用，因此必须被禁用。

默认情况下，日志表使用CSV存储引擎，即以逗号分隔的值格式写入数据。对于能够访问包含日志表数据的.CSV文件的用户来说，这些文件很容易导入其他程序，例如可以处理CSV输入的电子表格。

日志表可以被改变以使用MyISAM存储引擎。你不能使用ALTER TABLE来改变一个正在使用的日志表。必须先禁用该日志。除了CSV或MyISAM之外，其他引擎对日志表来说都是不合法的。

日志表和"太多打开文件（Too many open files）"的错误

如果你选择TABLE作为日志目标，并且日志表使用CSV存储引擎，你可能会发现在运行时反复禁用和启用通用查询日志或慢查询日志，导致为.CSV文件打开了很多文件描述符，可能会导致"Too many open files"错误。为了解决这个问题，执行FLUSH TABLES或者确保open_files_limit的值大于table_open_cache_instances的值。

要禁用日志记录来可以改变（或放弃）一个日志表，可以使用以下策略。这个例子使用了通用查询日志，慢查询日志的过程类似，只是使用了slow_log表和slow_query_log系统变量。

```mysql
SET @old_log_state = @@GLOBAL.general_log;
SET GLOBAL general_log = 'OFF';
ALTER TABLE mysql.general_log ENGINE = MyISAM;
SET GLOBAL general_log = @old_log_state;
```

TRUNCATE TABLE是对一个日志表的有效操作。它可以用于使日志条目过期。

RENAME TABLE是对一个日志表的有效操作。你可以使用以下策略原子化地重命名一个日志表（例如，执行日志轮换）。

```mysql
USE mysql;
DROP TABLE IF EXISTS general_log2;
CREATE TABLE general_log2 LIKE general_log;
RENAME TABLE general_log TO general_log_backup, general_log2 TO general_log;
```

CHECK TABLE是对一个日志表的有效操作。

LOCK TABLES不能用在一个日志表上。

INSERT, DELETE和UPDATE不能在一个日志表上使用。这些操作只允许在服务器本身的内部进行。

FLUSH TABLES WITH READ LOCK和read_only系统变量的状态对日志表没有影响。服务器总是可以向日志表写入。

写入日志表的条目不会被写入二进制日志，因此不会被复制到副本中。

要冲刷日志表或日志文件，分别使用FLUSH TABLES或FLUSH LOGS。

不允许对日志表进行分区。

mysqldump转储包括重新创建这些表的语句，以便在重新加载转储文件后它们不会丢失。日志表内容不被转储。

5 错误日志

5.1 内容和写入时机

错误日志包含mysqld启动和关闭时的记录。它还包含诊断信息，如在服务器启动和关闭期间以及在服务器运行时发生的错误、警告和注释。例如，如果mysqld注意到一个表需要自动检查或修复，它会向错误日志写一条消息。

在一些操作系统上，如果mysqld异常退出，错误日志包含一个堆栈跟踪。该跟踪可用于确定mysqld退出的位置。见第5.8节，"调试MySQL"。

如果使用mysqld_safe启动mysqld，mysqld_safe可能向错误日志写信息。例如，当mysqld_safe注意到mysqld异常退出时，它重新启动mysqld并将mysqld重新启动的消息写到错误日志中。

下面几节讨论了配置错误日志的各个方面。在讨论中，"控制台 "是指stderr，标准错误输出。这是你的终端或控制台窗口，除非标准错误输出已被重定向到一个不同的目的地。

包含在错误日志消息中的ID是mysqld中负责写消息的线程的ID。这表明服务器的哪个部分产生了该消息，并且与一般查询日志和慢速查询日志消息一致，后者包括连接线程ID。

5.2 相关配置

在Windows和Unix系统中，服务器对决定将错误信息写入何处的选项的解释有些不同。请确保使用适合你的平台的信息来配置错误记录。

在Unix和类Unix系统上，mysqld使用--log-error选项来决定mysqld是将错误日志写到控制台还是文件。

如果没有给出--log-error，mysqld将错误日志写到控制台。

如果给出--log-error而不指定文件，mysqld将错误日志写到数据目录中一个名为host_name.err的文件。

如果给出了--log-error来命名一个文件，mysqld会将错误日志写入该文件（如果名称没有后缀，则添加一个.err后缀）。文件位置在数据目录下，除非给出绝对路径名以指定不同的位置。

如果在[mysqld]、[server]或[mysqld_safe]部分的选项文件中给出了--log-error，在使用mysqld_safe启动服务器的系统中，mysqld_safe发现并使用该选项，并将其传递给mysqld。

注意
Yum或APT包的安装通常在服务器配置文件中用log-error=/var/log/mysqld.log这样的选项在/var/log下配置一个错误日志文件位置。移除选项中的路径名称会使数据目录中的host_name.err文件被使用。

如果服务器将错误日志写到控制台，它将log_error系统变量设置为stderr。否则，服务器会将错误日志写入一个文件，并将log_error设置为文件名。

log_syslog：可以让mysqld将错误日志写入系统日志（Windows上的Event Log，Unix和类Unix系统的syslog）。要做到这一点，请使用这些系统变量。

log_syslog。启用这个变量可以将错误日志发送到系统日志中。(在Windows上，log_syslog默认是启用的。)

如果log_syslog被启用，下面的系统变量也可以用来进行更精细的控制。

log_syslog_facility。syslog消息的默认设施是daemon。设置这个变量可以指定一个不同的设施。

log_syslog_include_pid: 是否在每一行的syslog输出中包括服务器进程ID。

log_syslog_tag: 这个变量定义了一个标签，在syslog消息中添加到服务器标识符(mysqld)上。如果定义了，该标签将被附加到标识符上，并在前面加一个连字符。

注意
向系统日志记录错误可能需要额外的系统配置。请参考你的平台的系统日志文档。

在Unix和类Unix系统中，使用mysqld_safe也可以控制输出到syslog，它可以捕获服务器错误输出并将其传递到syslog。

注意
使用mysqld_safe进行syslog错误记录已被废弃；你应该使用服务器系统变量来代替。

mysqld_safe有三个错误记录选项：--syslog，--skip-syslog，和--log-error。没有日志选项或使用--skip-syslog时，默认是使用默认的日志文件。要明确指定使用一个错误的日志文件，向mysqld_safe指定--log-error=file_name，然后安排mysqld将消息写到一个日志文件。要使用syslog，指定--syslog选项。对于syslog输出，可以用--syslog-tag=tag_val指定一个标签；它被附加到mysqld服务器标识符上，前面是连字符。

log_error_verbosity：控制服务器将错误、警告和备注信息写入错误日志的粗略程度。允许的值是1（只有错误），2（错误和警告），3（错误、警告和注释），默认值是3。 如果值大于2，服务器会记录中止的连接和新连接尝试的访问拒绝错误。参见B.3.2.9节，"通信错误和中止的连接"。

log_timestamps：系统变量控制写到错误日志（以及一般查询日志和慢速查询日志文件）的消息中的时间戳的时区。

允许的log_timestamps值是UTC（默认）和SYSTEM（本地系统时区）。时间戳使用ISO 8601 / RFC 3339格式编写。YYYY-MM-DDThh:mm:ss.uuuuu加上一个表示祖鲁时间（UTC）或±hh:mm（表示相对于UTC的本地系统时区调整的偏移）的尾部值Z。例如。

```mysql
2020-08-07T15:02:00.832521Z (UTC)
2020-08-07T10:02:00.832521-05:00 (SYSTEM)
```

5.3 运维操作

如果你使用FLUSH ERROR LOGS或FLUSH LOGS状态，或mysqladmin flush-logs命令冲洗错误日志，服务器会关闭并重新打开它正在写入的任何错误日志文件。要重命名一个错误日志文件，请在刷新前手动进行。冲洗日志后，会用原来的文件名打开一个新文件。例如，假设一个日志文件的名字是host_name.err，使用下面的命令来重命名该文件并创建一个新的文件。

```shell
mv host_name.err host_name.err-old
mysqladmin flush-logs
mv host_name.err-old backup-directory
```

在Windows上，使用rename而不是mv。

如果错误日志文件的位置不能被服务器写入，则日志刷新操作无法创建一个新的日志文件。例如，在Linux上，服务器可能将错误日志写到/var/log/mysqld.log文件，其中/var/log目录由root拥有，并且不能被mysqld写入。关于处理这种情况的信息，见第5.4.7节 "服务器日志维护"。

如果服务器没有写入一个命名的错误日志文件，当错误日志被刷新时，不会发生错误日志文件的重命名。

6 二进制日志

6.1 内容与写入时机

二进制日志包含描述数据库变化的 "事件"，如表的创建操作或对表数据的更改。它还包含有可能产生变化的语句的事件（例如，没有匹配行的DELETE），除非使用基于行的日志记录。二进制日志还包含关于每个更新数据的语句所花时间的信息。二进制日志不用于诸如SELECT或SHOW等不修改数据的语句。

二进制日志有两个重要目的。

对于复制来说，复制源服务器上的二进制日志提供了一个将被发送到副本的数据变化记录。源服务器将其二进制日志中包含的事件发送给其副本，副本执行这些事件，以做出与源服务器上相同的数据变化。见第16.2节，"复制的实现"。

某些数据恢复操作需要使用二进制日志。在备份被恢复后，二进制日志中在备份后记录的事件被重新执行。这些事件使数据库从备份点更新到最新。见第7.5节，"时间点（增量）恢复"。

在启用二进制日志的情况下运行服务器，性能会略微降低。然而，二进制日志在使你设置复制和恢复操作方面的好处通常超过了这种轻微的性能下降。

二进制日志通常对意外的停止有弹性，因为只有完整的事务被记录或读回。更多信息请参见第16.3.2节，"处理复制的意外停止"。

6.2 相关配置

下面描述了一些影响二进制日志操作的服务器选项和变量。关于完整的列表，请参阅第16.1.6.4节，"二进制日志选项和变量"。

下面的讨论描述了一些影响二进制日志操作的服务器选项和变量。关于完整的列表，请参阅第16.1.6.4节，"二进制日志选项和变量"。

要启用二进制日志，用--log-bin[=base_name]选项启动服务器。如果没有给出base_name值，默认的名字是-pid-file选项的值（默认是主机的名字），后面是-bin。如果给出了基数名，服务器会在数据目录中写入文件，除非基数名的前面有一个绝对路径名来指定一个不同的目录。建议你明确指定一个基名，而不是使用默认的主机名；原因见B.3.7节，"MySQL中已知的问题"。

如果你在日志名称中提供一个扩展名（例如，--log-bin=base_name.extension），扩展名会被默默地删除和忽略。

mysqld将一个数字扩展名附加到二进制日志基名，以生成二进制日志文件名。服务器每次创建一个新的日志文件时，该数字都会增加，从而创建一个有序的系列文件。每次发生以下任何事件时，服务器都会在该系列中创建一个新的文件。

服务器被启动或重新启动

服务器刷新了日志。

当前日志文件的大小达到max_binlog_size。

如果你使用大型事务，一个二进制日志文件可能会变得比max_binlog_size大，因为一个事务是一次性写入文件的，绝不会在文件之间分割。

为了跟踪哪些二进制日志文件已经被使用，mysqld还创建了一个二进制日志索引文件，其中包含二进制日志文件的名称。默认情况下，它的基本名称与二进制日志文件相同，扩展名为'.index'。你可以用--log-bin-index[=file_name]选项来改变二进制日志索引文件的名称。当mysqld运行时，你不应该手动编辑这个文件；这样做会使mysqld混淆。

术语 "二进制日志文件 "通常表示一个包含数据库事件的单独的编号文件。术语 "二进制日志 "统称为一组编号的二进制日志文件加上索引文件。

一个拥有足够权限设置限制性会话系统变量的客户（参见章节5.1.8.1, "系统变量权限"）可以通过使用SET sql_log_bin=OFF语句来禁止对自己的语句进行二进制日志记录。

默认情况下，服务器会记录事件的长度以及事件本身，并使用它来验证事件是否被正确写入。你也可以通过设置binlog_checksum系统变量使服务器为事件写入校验和。当从二进制日志中读回时，源程序默认使用事件长度，但如果有的话，可以通过启用master_verify_checksum系统变量使其使用校验和。复制的I/O线程也会验证从源头收到的事件。你可以通过启用slave_sql_verify_checksum系统变量，使复制的SQL线程在从中继日志读取时使用校验和（如果有的话）。

记录在二进制日志中的事件的格式取决于二进制日志格式。支持三种格式类型，基于行的日志记录、基于语句的日志记录和混合基础的日志记录。使用的二进制日志格式取决于MySQL版本。关于日志格式的一般描述，见第5.4.4.1节，"二进制日志格式"。关于二进制日志格式的详细信息，见MySQL内部。二进制日志。

服务器评估-binlog-do-db和-binlog-ignore-db选项的方式与评估--replicate-do-db和--replicate-ignore-db选项的方式相同。关于如何做到这一点的信息，请参阅第16.2.5.1节，"数据库级复制和二进制日志选项的评估"。

在默认情况下，一个复制体不会把从源头收到的任何数据修改写到自己的二进制日志中。要记录这些修改，除了-log-bin选项外，还要用-log-slave-updates选项来启动复制（参见16.1.6.3节，"复制服务器选项和变量"）。当一个副本在链式复制中作为其他副本的源时，就会这样做。

你可以用RESET MASTER语句删除所有二进制日志文件，或者用PURGE BINARY LOGS删除其中的一个子集。参见第13.7.6.6节 "RESET语句 "和第13.4.1.1节 "PURGE BINARY LOGS语句"。

如果你正在使用复制，你不应该删除源上的旧二进制日志文件，直到你确定没有副本还需要使用它们。例如，如果你的复制从未落后超过三天，每天一次你可以在源上执行mysqladmin flush-logs，然后删除任何超过三天的日志。你可以手动删除这些文件，但最好是使用PURGE BINARY LOGS，它也可以为你安全地更新二进制日志索引文件（并且可以接受一个日期参数）。参见第13.4.1.1节，"PURGE BINARY LOGS语句"。

你可以用mysqlbinlog工具显示二进制日志文件的内容。当你想为恢复操作重新处理日志中的语句时，这可能很有用。例如，你可以从二进制日志中更新一个MySQL服务器，如下所示。

shell> mysqlbinlog log_file | mysql -h server_name
mysqlbinlog也可以用来显示中继日志文件的内容，因为它们是使用与二进制日志文件相同的格式写入的。关于mysqlbinlog工具的更多信息以及如何使用它，见第4.6.7节 "mysqlbinlog-处理二进制日志文件的工具"。关于二进制日志和恢复操作的更多信息，见第7.5节 "时间点（增量）恢复"。

二进制日志是在语句或事务完成后，但在任何锁被释放或任何提交被完成之前立即进行。这确保了日志是按照提交顺序记录的。

对非交易表的更新在执行后立即存储在二进制日志中。

在一个未提交的事务中，所有改变事务表（如InnoDB表）的更新（UPDATE、DELETE或INSERT）被缓存，直到服务器收到COMMIT语句。在这一点上，mysqld在执行COMMIT之前将整个事务写入二进制日志。

对非事务性表的修改不能回滚。如果一个被回滚的事务包括对非事务表的修改，整个事务会以ROLLBACK语句结尾进行记录，以确保对这些表的修改被复制。

当一个处理事务的线程开始时，它分配一个binlog_cache_size的缓冲区来缓冲语句。如果一个语句大于这个大小，线程就会打开一个临时文件来存储该事务。当线程结束时，该临时文件被删除。

binlog_cache_use状态变量显示了使用这个缓冲区（可能还有一个临时文件）来存储语句的事务数量。binlog_cache_disk_use状态变量显示了其中有多少事务实际上使用临时文件。这两个变量可以用来调整binlog_cache_size到一个足够大的值，避免使用临时文件。

max_binlog_cache_size系统变量（默认为4GB，这也是最大值）可以用来限制用于缓存一个多语句事务的总大小。如果一个事务大于这个字节数，它就会失败并回滚。最小值是4096。

如果你使用二进制日志和基于行的日志，对于CREATE ... SELECT或INSERT ... SELECT语句的并发插入将被转换为普通插入。这样做是为了确保你可以通过在备份操作中应用日志来重新创建一个精确的表的副本。如果你使用的是基于语句的日志记录，那么原始的语句会被写入日志中。

二进制日志格式有一些已知的限制，会影响到从备份中恢复。见第16.4.1节，"复制功能和问题"。

存储程序的二进制日志是按照第23.7节 "存储程序二进制日志 "中的描述进行的。

请注意，由于复制的增强，MySQL 5.7中的二进制日志格式与以前版本的MySQL不同。见第16.4.2节，"MySQL版本之间的复制兼容性"。

如果服务器无法写入二进制日志、刷新二进制日志文件或将二进制日志同步到磁盘，源上的二进制日志可能变得不一致，复制可能失去与源的同步。binlog_error_action系统变量控制在二进制日志遇到这种类型的错误时所采取的行动。

默认设置，ABORT_SERVER，使服务器停止二进制日志记录并关闭。在这一点上，你可以识别并纠正错误的原因。在重新启动时，恢复工作与服务器意外停止的情况一样进行（参见第16.3.2节，"处理副本的意外停止"）。

IGNORE_ERROR设置提供了与旧版本MySQL的向后兼容性。有了这个设置，服务器继续进行正在进行的交易并记录错误，然后停止二进制记录，但继续执行更新。在这一点上，你可以确定并纠正错误的原因。要恢复二进制日志记录，必须再次启用log_bin，这需要重新启动服务器。只有在你需要向后兼容，并且二进制日志在这个MySQL服务器实例上是非必要的情况下才使用这个选项。例如，你可能只将二进制日志用于服务器的间歇性审计或调试，而不将其用于服务器的复制或依赖它进行时间点恢复操作。

默认情况下，二进制日志在每次写入时都会同步到磁盘（sync_binlog=1）。如果没有启用sync_binlog，而操作系统或机器（不仅是MySQL服务器）崩溃了，有可能会丢失二进制日志的最后几条语句。为了防止这种情况，请启用sync_binlog系统变量，在每N个提交组之后将二进制日志同步到磁盘。参见第5.1.7节，"服务器系统变量"。sync_binlog的最安全值是1（默认值），但这也是最慢的。

例如，如果你使用InnoDB表，并且MySQL服务器处理一个COMMIT语句，它将许多准备好的事务依次写入二进制日志，同步二进制日志，然后将该事务提交到InnoDB。如果服务器在这两个操作之间意外退出，该事务在重新启动时被InnoDB回滚，但仍然存在于二进制日志中。假设-innodb_support_xa被设置为1，即默认值，这样的问题就可以解决。尽管这个选项与InnoDB中对XA事务的支持有关，但它也确保了二进制日志和InnoDB的数据文件是同步的。为了使这个选项提供更高的安全性，MySQL服务器也应该被配置为在提交事务之前将二进制日志和InnoDB日志同步到磁盘。InnoDB日志默认是同步的，而sync_binlog=1可以用来同步二进制日志。这个选项的效果是，在崩溃后重新启动时，在做完事务回滚后，MySQL服务器会扫描最新的二进制日志文件以收集事务的xid值，并计算出二进制日志文件中最后的有效位置。然后，MySQL服务器告诉InnoDB完成任何成功写入二进制日志的准备好的事务，并将二进制日志截断到最后的有效位置。这确保了二进制日志反映了InnoDB表的准确数据，因此副本与源保持同步，因为它没有收到已经回滚的语句。

注意
innodb_support_xa已被废弃；预计在未来的版本中会被移除。从MySQL 5.7.10开始，InnoDB对XA事务中的两阶段提交的支持总是被启用。

如果MySQL服务器在崩溃恢复时发现二进制日志比它应该有的短，它至少缺少一个成功提交的InnoDB事务。如果sync_binlog=1和磁盘/文件系统在被要求时做实际的同步（有些不做），这种情况就不应该发生，所以服务器会打印一个错误信息 The binary log file_name is shorter than its expected size. 在这种情况下，这个二进制日志是不正确的，复制应该从源的数据的新快照重新开始。

以下系统变量的会话值被写入二进制日志，并在解析二进制日志时被复制体所认可。

sql_mode (except that the NO_DIR_IN_CREATE mode is not replicated; see Section 16.4.1.37, “Replication and Variables”)

foreign_key_checks

unique_checks

character_set_client

collation_connection

collation_database

collation_server

sql_auto_is_null

6.3 日志格式

服务器使用几种日志格式来记录二进制日志中的信息。采用的确切格式取决于正在使用的MySQL版本。有三种日志格式。

MySQL的复制功能最初是基于从源到副本的SQL语句的传播。这被称为基于语句的日志记录。你可以通过用-binlog-format=STATEMENT启动服务器来导致使用这种格式。

在基于行的日志记录中，源文件将事件写到二进制日志中，表明单个表的行是如何被影响的。因此，重要的是，表总是使用一个主键，以确保行可以被有效地识别。你可以通过使用-binlog-format=ROW启动服务器，使其使用基于行的日志记录。

第三个选项也是可用的：混合日志记录。在混合日志中，默认使用基于语句的日志，但在某些情况下，日志模式会自动切换到基于行的，如下所述。你可以通过用选项-binlog-format=MIXED启动mysqld，使MySQL明确地使用混合日志记录。

日志格式也可以由正在使用的存储引擎设置或限制。这有助于消除在使用不同存储引擎的源和副本之间复制某些语句的问题。

在基于语句的复制中，可能会出现复制非确定性语句的问题。在决定一个给定的语句对于基于语句的复制是否安全时，MySQL确定它是否可以保证该语句可以使用基于语句的日志进行复制。如果MySQL不能做出这种保证，它就会将该语句标记为潜在的不可靠，并发出警告：Statement may not be safe to log in statement format。

你可以通过使用MySQL的基于行的复制来避免这些问题。

日志格式也可以在运行时切换，不过要注意，在一些情况下不能这样做。

binlog_format有全局和会话两个作用范围。改变全局binlog_format值需要足够的权限来设置全局系统变量。改变会话binlog_format值需要足够的权限来设置限制性会话系统变量。

客户可能想在每个会话的基础上设置二进制日志，这有几个原因。

对数据库进行许多小改动的会话可能希望使用基于行的日志记录。

一个执行与WHERE子句中许多行相匹配的更新的会话可能想使用基于语句的日志记录，因为记录一些语句比记录许多行更有效。

有些语句在源上需要大量的执行时间，但只导致几条行被修改。因此，使用基于行的日志记录来复制它们可能是有益的。

不能在运行时切换复制格式的情况：

从一个存储函数或触发器内。

如果NDB存储引擎被启用。

如果会话当前处于基于行的复制模式并且有开放的临时表。

在任何这些情况下尝试切换格式都会导致错误。

当存在任何临时表时，不建议在运行时切换复制格式，因为临时表只在使用基于语句的复制时被记录，而在基于行的复制时，它们不会被记录。在混合复制中，临时表通常会被记录；可加载函数和UUID()函数会有例外。

在复制进行时切换复制格式也会导致问题。每个MySQL服务器都可以设置它自己的且仅是它自己的二进制日志格式（无论binlog_format是用全局范围还是会话范围设置的，都是真的）。这意味着改变复制源服务器上的日志格式不会导致副本改变其日志格式来匹配。当使用STATEMENT模式时，binlog_format系统变量不会被复制。当使用MIXED或ROW日志模式时，它被复制但被复制体忽略。

一个副本不能将收到的ROW日志格式的二进制日志条目转换为STATEMENT格式，以用于它自己的二进制日志。因此，如果源文件使用ROW或MIXED格式，副本必须使用。在复制过程中，将源的二进制日志格式从STATEMENT改为ROW或MIXED，而复制又是在STATEMENT格式的副本中进行的，会导致复制失败，出现诸如执行行事件错误。不能执行语句：无法写入二进制日志，因为语句是行格式，而BINLOG_FORMAT = STATEMENT。为了安全地改变格式，你必须停止复制，并确保在源和副本上都做同样的改变。

如果你使用InnoDB表，并且事务隔离级别是READ COMMITTED或READ UNCOMMITTED，那么只能使用基于行的日志记录。可以将日志格式改为STATEMENT，但是在运行时这样做会很快导致错误，因为InnoDB不能再执行插入。

在二进制日志格式设置为ROW的情况下，许多变化是使用基于行的格式写入二进制日志的。然而，有些变化仍然使用基于语句的格式。例子包括所有的DDL（数据定义语言）语句，比如CREATE TABLE，ALTER TABLE，或者DROP TABLE。

--binlog-row-event-max-size选项对能够进行基于行的复制的服务器可用。行被存储到二进制日志中，其大小以字节为单位，不超过该选项的值。该值必须是256的倍数。默认值是8192。

警告
当使用基于语句的日志进行复制时，如果语句的设计方式使数据的修改是不确定的，也就是说，它是由查询优化器来决定的，那么源数据和副本的数据就有可能变得不同。一般来说，即使在复制之外，这也不是一个好的做法。关于这个问题的详细解释，见B.3.7节 "MySQL中已知的问题"。

6.4 mixed格式

https://dev.mysql.com/doc/refman/5.7/en/binary-log-mixed.html

6.5 对mysql库的操作在二进制日志中的体现

mysql数据库中授予表的内容可以直接（例如，用INSERT或DELETE）或间接（例如，用GRANT或CREATE USER）被修改。影响mysql数据库表的语句使用以下规则写到二进制日志中。

直接改变mysql数据库表中数据的数据操作语句，根据binlog_format系统变量的设置进行记录。这与INSERT、UPDATE、DELETE、REPLACE、DO、LOAD DATA、SELECT和TRUNCATE TABLE等语句有关。

无论binlog_format的值如何，间接改变mysql数据库的语句都被记录为语句。这与GRANT、REVOKE、SET PASSWORD、RENAME USER、CREATE（所有形式，除了CREATE TABLE ... SELECT）、ALTER（所有形式）和DROP（所有形式）等语句有关。

CREATE TABLE ... SELECT是一个数据定义和数据操作的组合。CREATE TABLE部分使用语句格式进行记录，SELECT部分根据binlog_format的值进行记录。

6.6 重写

见通用查询日志。参见第6.1.2.3节，"密码和日志记录"。

7 日志维护

如第5.4节 "MySQL服务器日志 "中所述，MySQL服务器可以创建几个不同的日志文件，以帮助你看到正在发生的活动。然而，你必须定期清理这些文件，以确保日志不会占用太多的磁盘空间。

当使用启用了日志记录的MySQL时，你可能要不时地备份和删除旧的日志文件，并告诉MySQL开始向新的文件记录日志。见第7.2节，"数据库备份方法"。

在Linux（Red Hat）安装中，你可以使用mysql-log-rotate脚本进行日志维护。如果你从RPM发行版中安装MySQL，这个脚本应该已经自动安装。如果你使用二进制日志进行复制，要小心使用这个脚本。你不应该删除二进制日志，直到你确定它们的内容已经被所有的复制体处理。

在其他系统上，你必须自己安装一个简短的脚本，从cron（或其等价物）启动，用于处理日志文件。

对于二进制日志，你可以设置expire_logs_days系统变量，使二进制日志文件在指定天数后自动过期（参见第5.1.7节，"服务器系统变量"）。如果你正在使用复制，你应该将该变量设置为不低于你的复制可能滞后于源的最大天数。要按要求删除二进制日志，请使用PURGE BINARY LOGS语句（见第13.4.1.1节，"PURGE BINARY LOGS语句"）。

要迫使MySQL开始使用新的日志文件，请冲刷日志。当你执行FLUSH LOGS语句或mysqladmin flush-logs、mysqladmin refresh、mysqldump --flush-logs或mysqldump --master-data命令时，会发生日志冲刷。参见第13.7.6.3节 "FLUSH语句"，第4.5.2节 "mysqladmin--一个MySQL服务器管理程序"，以及第4.5.4节 "mysqldump--一个数据库备份程序"。此外，当当前二进制日志文件大小达到max_binlog_size系统变量的值时，服务器会自动刷新二进制日志。

FLUSH LOGS支持可选的修饰词，以实现对单个日志的选择性刷新（例如，FLUSH BINARY LOGS）。参见第13.7.6.3节，"FLUSH语句"。

日志刷新操作有以下效果。

如果启用了二进制日志，服务器会关闭当前的二进制日志文件，并以下一个序列号打开一个新的日志文件。

如果启用了一般查询日志或慢速查询日志到一个日志文件，服务器会关闭并重新打开日志文件。

如果服务器是用--log-error选项启动的，使错误日志被写到一个文件中，那么服务器会关闭并重新打开日志文件。

执行日志刷新语句或命令需要使用具有RELOAD权限的账户连接到服务器。在Unix和类Unix系统中，另一种冲洗日志的方法是向服务器发送一个SIGHUP信号，这可以由root或拥有服务器进程的账户来完成。信号使日志刷新可以在不需要连接到服务器的情况下进行。然而，SIGHUP有除日志刷新之外的其他效果，可能是不可取的。详见第4.10节，"MySQL中的Unix信号处理"。

如前所述，刷新二进制日志会创建一个新的二进制日志文件，而刷新一般查询日志、慢速查询日志或错误日志只是关闭和重新打开日志文件。对于后一种日志，要想在Unix系统中导致一个新的日志文件被创建，在冲刷之前先重命名当前的日志文件。在冲刷时，服务器会用原来的名字打开新的日志文件。例如，如果一般查询日志、慢速查询日志和错误日志文件被命名为mysql.log、mysql-slow.log和err.log，你可以在命令行中使用一系列这样的命令。

cd mysql-data-directory
mv mysql.log mysql.log.old
mv mysql-slow.log mysql-slow.log.old
mv err.log err.log.old
mysqladmin flush-logs
在Windows上，使用rename而不是mv。

在这一点上，你可以对mysql.log.old、mysql-slow.log.old和err.log.old进行备份，然后从磁盘中删除它们。

要在运行时重命名一般查询日志或慢速查询日志，首先连接到服务器并禁用该日志。

SET GLOBAL general_log = 'OFF';
设置GLOBAL slow_query_log = 'OFF'。
禁用日志后，从外部重命名日志文件（例如，从命令行）。然后再次启用日志。

SET GLOBAL general_log = 'ON';
SET GLOBAL slow_query_log = 'ON';
这种方法可以在任何平台上使用，而且不需要重新启动服务器。

注意事项
在你从外部重命名一个给定的日志文件后，服务器要重新创建该文件，该文件的位置必须是可以被服务器写入的。这可能并不总是如此。例如，在Linux上，服务器可能将错误日志写成/var/log/mysqld.log，其中/var/log由root拥有，并且不能被mysqld写入。在这种情况下，日志刷新操作无法创建一个新的日志文件。

为了处理这种情况，你必须在重命名原日志文件后，以适当的所有权手动创建新的日志文件。例如，以root身份执行这些命令。

mv /var/log/mysqld.log /var/log/mysqld.log.old
install -omysql -gmysql -m0644 /dev/null /var/log/mysqld.log