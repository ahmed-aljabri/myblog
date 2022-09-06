---
title: "#01 Dethroning TCP from The Web"
date: 2022-08-13T13:44:46Z
draft: false
toc: false
images:
tags:
  - QUIC
  - TCP
  - Networking
  - HTTP3
  - Multiplexing
---

> **Latest Revision: 03/09/2022**

#### prerequisites

The reader should have some understanding of basic networking concepts such as the OSI protocol layers, how the web and in particular HTTP works.
___
## Abstract
Ever since Tim Burners-Lee created the World Wide Web, TCP has been the main and in most cases the only option providing reliable transport to web exchanges. Understandably, TCP was the obvious option since web exchanges required reliability to exchange web content. However as HTTP continued to evolve throughout the years to fit the needs of the evolving web, TCP's limitations continued to prevail. Up until recently when HTTP/3 officially marked a new era for web transport, TCP is swapped out of the HTTP protocol stack for QUIC which operates on top of UDP. Consequently, as implementations of HTTP/3 increase to reap the benefits of this latest version of HTTP, QUIC and UDP are set to gradually dethrone TCP as the web's most dominant transport protocol.

## Introduction

As we have always known the web, the Transport Control Protocol ([TCP](https://www.cloudflare.com/en-gb/learning/ddos/glossary/tcp-ip/)) has mainly been the appropriate transport
protocol to use for [HTTP](https://www.cloudflare.com/en-gb/learning/ddos/glossary/hypertext-transfer-protocol-http/) exchanges. Given the limited number of well
established transport protocols as opposed to other layers, it was obvious that TCP’s main features best
fit the design needs of the web, providing packet reordering, retransmission and congestion control to ultimately
maintain the reliability and scalability of communications on unreliable networks.<br>

As the web evolved drastically since its beginning, HTTP has underwent a number of revisions (HTTP/1.0, HTTP/1.1,
HTTP/2 and lately HTTP/3 ) while TCP relatively remained the same and only had minor tweaks over the years.
This is due to fact that HTTP being an application layer protocol (user-side) is more flexible to improvements unlike TCP which is a low level protocol (kernel-side). Although this is may be obvious, it is extremely important to highlight this point as it sheds light to a major issues faced by engineers in this case.

## Uncovering TCP's limitations
In the early days of the web, there were relatively few requests occurring in a single web transaction, sometimes a
single HTTP request to fetch the HTML page is all that was needed to take place. Web pages were much simpler
than what we see nowadays and as a result, early HTTP versions were sufficient for that purpose.
However, if we look at how HTTP worked in early versions and continued to evolve we can understand how
future requirements of the web could not be fulfilled by the same underlying technologies.
In the following subsections HTTP’s evolution is explained to establish a better understanding of how we got
to this stage.

### HTTP/1.0

HTTP/1.0 was the first HTTP version standardised by the Internet Engineering Task Force (IETF) in 1995. The
specifications of how web exchanges operate is illustrated in the figure below.

![HTTP/1.0](/img/HTTP1_0_Sequence.drawio.png)

As presented above, in a typical HTTP/1.0 exchange, a TCP connection is established to facilitate the transport
of a single HTTP exchange (HTTP Request & Response) and then immediately terminated. This means that for every HTTP exchange the client
will need to establish a new TCP connection with the server which does not seem effective nevertheless, it was sufficient enough for fetching simple static sites in the early days of the web. If all that was needed to be fetched
was a HTML and CSS file then this approach is convenient enough.
However, it is obvious how limited and unscalable this approach becomes if more HTTP exchanges are to take
place. Hence, the arrival of HTTP/1.1 just a year later.

### HTTP/1.1

What HTTP/1.1 mainly aimed to achieve was the ability to consume TCP connections more efficiently, specifically
by exchanging multiple HTTP exchanges per TCP connections as illustrated in the diagram below. This approach was instantly
more effective than HTTP/1.0 since TCP connections are now kept "alive" until all needed HTTP exchanges were
completed.

![HTTP/1.1](/img/HTTP1_1_Sequence.drawio.png)


More so, this version of HTTP introduced the concept of __Pipelining__ that allows the client to send
subsequent HTTP requests without needing to wait for each corresponding response to be processed. This was also
a major performance advancement since in previous versions, subsequent requests could not be sent until the
response of the previous request has been received and processed.

Nevertheless, HTTP/1.1 still left room for improvement. Mainly in the fact that from the server’s
perspective, responses are not sent until all subsequent requests are processed. For example in the figure above, even though request #1 arrives first, it is not responded to until request #3 has been processed. This is not ideal in the web domain as some requests can be unrelated to others and for that reason they should not be slowed down by later requests.

To get around this issue, specifications suggested that clients can establish up to 6 TCP connections with a
server as shown in figure 3. This way each request can be assigned a dedicated TCP connection, where this will
make HTTP requests sent in different TCP connections independent and so the server can
respond to them faster independently.

![HTTP/1.1 6 TCP Connections](/img/6TCPStreams.drawio.png)

This however was not an efficient solution for a number of reasons. Firstly the high resource consumption of
CPU time for servers to maintain up to 6 TCP connections for each client. Secondly the ripple effect of increasing
number of packets in a network when establishing each TCP connection (TCP Handshake packets).
Despite the limitations, HTTP/1.1 worked well and was not succeeded until about a decade later. The arrival of HTTP/2 enhanced the performance and efficiency of web exchanges but also shed light to major TCP limitations that eventually led to
the development of QUIC.

### HTTP/2

Working around the previous version’s limitations, HTTP/2 implemented the concept of __Multiplexing__ that essentially
assigned HTTP requests independent streams that can share a single TCP connection. This way HTTP
exchanges can be processed independently without the need to establish multiple TCP connections as done in HTTP/1.1.

![HTTP/2](/img/HTTP2_Sequence.drawio.png)


The performance benefits however could not be fully realized due to TCP’s byte-stream view of data that it receives from other layers. As a
result, data in independent HTTP2 streams at the application layer will be interpreted as a whole stream of bytes by TCP at the transport layer as shown in the following diagram. 

![TCP's stream perspective](/img/HTTP2HOF.drawio.png)

This observation highlights an important limitation which is that the to fully reap the benefits of multiplexing at the application layer (which is what HTTP2 did by introducing streams), multiplexing must also be supported at the transport layer, otherwise as the example next will illustrate, the performance limitations will still be experienced.

For instance when visiting a webpage consisting of multiple unrelated images of varying sizes, HTTP/2 streams are ideal for 
assigning each image an independent stream as illustrated above. Nevertheless, when those streams are passed down to the transport layer, TCP will interpret all of the individual streams
as one. Therefore, at the receiving end the server will not be able to process any of the image requests until all
requests have successfully arrived. In the figure above we see that images A, B and C although assigned independent streams by HTTP, are all sent as one stream of bytes and as a result when image A experienced some loss in transmission, the entire stream (containing all three images) waits for the retransmission before being processed at the receiving end. This limitation is referred to as __head-of-line-blocking__ and as a consequence, this slows down the processing at the receiving end which limits the ability of HTTP2 to realize all it's intended performance benefits.

At this stage, we understand that for the web to continue to enhance it's performance, the focus needs to shift from the application layer to the transport layer where the main limitation lies. And hence, potential solutions to overcome this limitation were mainly among two theoretical options. One, to improve
TCP’s implementation so that multiplexing is supported at the transport layer. Two, to develop a new “transport”
protocol that will understand the concept of streams and implement multiplexing.

It might first seem that enhancing an established protocol is the more efficient and reasonable solution rather than
developing one from scratch. However in this case it is in fact the opposite. TCP is a legacy kernel-side protocol
that has been used in the internet for over 40 years, to introduce a major change to such an established protocol
would practically mean to change TCP’s implementation in major vendors system’s kernals. This would also include
deploying changes to middle-boxes across the internet and not just end-systems which is simply not practical in
today's networks. This issue is often referred to as “Ossification” which is a topic in itself that deserves a dedicated blog post.

## Emergence of QUIC

Due to the limitations described above, development efforts kicked off at Google in 2013 to develop a
new transport protocol which we know today as QUIC. The initial efforts centered around developing a multiplexed
transport protocol that will further enhance HTTP's performance. Later in 2015, the QUIC efforts were moved to the Internet Engineering Task Force (IETF) which desired to make QUIC an independent transport protocol that can benefit other application layer protocols and not just HTTP.

As mentioned briefly in the previous section, implementing major changes to TCP is not a practical option and so QUIC was designed to instead use UDP as transport but on top of that reused some of TCP's crucial features (packet reordering, retransmission and congestion control) and added additional features (such as multiplexing) that will enhance the performance of the web.

>Note: QUIC has other additional features such as connection migration, 0-RTT, embedded TLS1.3 and more that this post does not delve deep into as they are not directly related to the current topic.

![QUIC stream perspective](/img/HTTP3Streams.drawio.png)

The illustration above shows how QUIC is designed to be capable of multiplexing at the transport layer. When each of the HTTP streams are passed down to QUIC, independent __QUIC Streams__ are assigned at the transport layer which allows the receiving end to distinguish between the incoming streams and consequently, be able to process and respond to them independently as soon as soon as they arrive thereby achieving the full benefits of multiplexing. Comparing this to the previous example in HTTP2, QUIC can assign each of the images an independent stream and so if one stream relating to image A is affected, only that stream awaits retransmission while streams of image B and C are processed therefore avoiding the head-of-line blocking problem with TCP.

With that capability to multiplex at the transport layer, HTTP3 is now officially a standard protocol ([RFC 9114](https://datatracker.ietf.org/doc/html/rfc9114)) that swaps out TCP from the protocol suite for QUIC and UDP. Performance tests have showed that in high speed networks with low packet loss rates the performance gains are insignificant while on low performance networks with higher packet loss rates, QUIC out-preforms older TCP implementations by notable margins (see [this](https://research.google/pubs/pub46403/) paper).  

## Final thoughts
In summary, with the standardisation of HTTP3, a major shift takes place within the underlying technologies that allowed the web to operate as we know for decades. Although the main protocol that is synonymous with the web (HTTP) remains relatively unchanged from HTTP2 to HTTP3, TCP is no longer the transport protocol for web exchanges. Instead, QUIC on top of UDP replaces TCP at the transport layer which highlights a few final points:

- As the complexity of webpages continue to grow, more transitions to deploy HTTP3 are expected to gain more performance. This would consequently mean that slowly but eventually TCP will no longer be the most dominant transport protocol __in the web domain__ and QUIC on top of UDP will take its place. In fact in 2017, way before QUIC was standardized, 7% of internet traffic was running on QUIC according to Google who themselves implemented it. A more recent statistic shows that the figure has risen to 12% midway through 2021.

- This begins a new era in the web domain where TCP is no longer synonymous with HTTP, QUIC provides a way of having reliable and secure transport features without having to take the performance burdens of legacy technologies such as TCP. 

- With QUIC being standardized as an independent transport protocol, we are set to see other application layer protocols that value latency and other metrics of performance move to QUIC such as DNS. This is a promising area to watch out for as other domains outside the web start to consider the move to QUIC.
  

  