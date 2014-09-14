MultiHop
========

implemented platform: TinyOS

This project is developed to form a data collection tree. The gateway node collects all data sent by the end nodes that are sent to the PC via serial port to be stored in the data base for further analysis. Link layer acknowledgement is provided for every packet that is sent. Every packet that does not receive an acknowledgement is retransmitted after certain duration to avoid collision.

All end nodes are connected to sensor board to acquire sensor readings which are sent to the Root node. The nodes also send a 1000 byte file which is fragmented at the node itself and sent over the network. The root node reassembles the fragments according to the sequence number in which fragment to construct back the file.
This project forms the basis of a multi hop self-configuring and self-organizing network that can be used for different applications in a variety of fields.
