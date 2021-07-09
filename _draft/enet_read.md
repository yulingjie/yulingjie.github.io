# 关于可靠UDP的实现与设计（阅读enet源码)

## 实现一个可靠UDP需要考虑哪些问题？
+ 超时重传；
+ 可重传消息与不可重传消息；
+ 连续stream seq;
+ rtt的衡量
+ 时间戳的同步
+ 窗口大小，滑动窗口；
+ connection maintain, 不能靠IP维持，地址会变化；
+ Flow Control;
+ Congestion Control;



## 目前自己gonet的实现进度
+ 单Seq 单Ack的消息发送


## enet设计


## pipelined udp message
### GBN
    Go Back N设计方法。Seq 与 Ack字段由原来的1bit扩展到8bit,这意味着最多可以维持256个未确认的消息。发送方维持base与nextsend两个序号，base指未确认的起始index，nextsend指发送的消息下一个可以用的序号，同时发送方需要维持一个窗口大小，目前先固定为64；
    接收方接单的维持一个nextrecv消息即可，用来记录接下来需要接受的消息序号。如果收到的消息不等于nextrecv，意味着当前消息接受出现乱序、丢包或者其他，此时接收方简单的将此消息包丢弃，并返回last in-order ack。
    接收方采取accumulated acknowledge方式，接收方放回的ack序号，表示此序号以及此序号之前的消息都正确的接受完毕。
    发送方收到ack时，表示这个ack及之前的消息都收到了，发送方将base移动到ack+1，发送窗口滑动；
    在发送消息以及每次收到消息消息ACK时重新刷新Timer，并且在消息base == nextsend停止计时器；
    超时后，直接将base -> nextsend -1 之间的所有消息全部重新发送。
    目前我的实现并没有考虑消息完整性检查。
    
