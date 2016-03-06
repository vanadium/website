= yaml =
title: Vanadium Performance
toc: true
= yaml =

Performance of the Vanadium APIs is measured with microbenchmarks.
[benchmarks.v.io] records these results at various snapshots of the codebase
and on  multiple platforms. Since the total number of benchmarks served by
[benchmarks.v.io] is somewhat overwhelming, this page lists out a small subset
that can be considered representative of Vanadium.

The numbers below are for using the Go API. Benchmarks for other languages
(Java in particular) are not integrated into the flow of continuous measurement
yet, but are intended to be.

All the numbers are currently one click away. We hope to restructure this page
to embed live results to avoid that one click in the future.

# RPC
In all the benchmarks here, network round-trip time is zero. Thus, when RPCs
are executed 'in the wild', network round-trip time must be added.

## Connection Establishment

Results: <a href="https://benchmarks.v.io/?q=v.io%2Fx%2Fref%2Fruntime%2Finternal%2Frpc%2Fbenchmark.BenchmarkConnectionEstablishment+uploader%3Avlab#">v.io/x/ref/runtime/internal/rpc/benchmark.BenchmarkConnectionEstablishment</a>

Establishment of a mutually authenticated, confidential network connection
between two processes. This includes the time it takes to establish a TCP
connection and execute the [Vanadium authentication protocol] over it.

## Echo

Results: <a href="https://benchmarks.v.io/?q=v.io%2Fx%2Fref%2Fruntime%2Finternal%2Frpc%2Fbenchmark.Benchmark____1B+uploader%3Avlab#">v.io/x/ref/runtime/internal/rpc/benchmark.Benchmark____1B</a>

Sending a 1 byte "echo" request and receiving the response over an established
connection. The Vanadium RPC protocol multiplexes RPCs over a single
established connection.

# Syncbase

## Put

Results: <a href="https://benchmarks.v.io/?q=v.io%2Fv23%2Fsyncbase%2Fnosql.BenchmarkTinyPut+uploader%3Avlab#">v.io/v23/sycnbase/nosql.BenchmarkTinyPut</a>.

Writing a small piece of structured information to the syncbase daemon via the
[Table](https://godoc.org/v.io/v23/syncbase/nosql#Table) API.

## Get

Results: <a href="https://benchmarks.v.io/?q=v.io%2Fv23%2Fsyncbase%2Fnosql.BenchmarkTinyGet+uploader%3Avlab#">v.io/v23/sycnbase/nosql.BenchmarkTinyGet</a>.

Reading read a small piece of structured information from the syncbase daemon
via the [Table](https://godoc.org/v.io/v23/syncbase/nosql#Table) API.

## Sync

Results: <a href="https://benchmarks.v.io/?q=v.io%2Fv23%2Fsyncbase%2Ffeaturetests.BenchmarkPingPongPair+uploader%3Avlab#">v.io/v23/syncbase/featuretests.BenchmarkPingPongPair</a>.

As of February 2016, this measures 500x the time it takes for peers in a
syncgroup to notice updates made to each other. For example, on desktop/laptop
class machines [benchmarks.v.io] reported 1m40s, which means 100/500 seconds =
200ms to sync an update. The 500x multiplier is an artifact of the benchmark
implementation, not the sync protocol.

This also includes any idle time between attempts to contact the peer syncbase
instance for updates. Changes to the sync protocol (changing the polling
interval or using a push-notification mechanism) were being iterated on at the
time of this writing. These numbers are very sensitive to such changes.

[benchmarks.v.io]: https://benchmarks.v.io
[Vanadium authentication protocol]: /designdocs/authentication.html
