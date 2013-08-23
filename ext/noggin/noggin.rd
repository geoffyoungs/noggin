= module Noggin
--- Noggin.destinations()


--- Noggin.jobs(String printer, Boolean mine, Integer whichjobs)


--- Noggin.ippRequest(Integer operation, request_attributes)


== Noggin::WHICHJOBS_ALL
== Noggin::WHICHJOBS_ACTIVE
== Noggin::WHICHJOBS_COMPLETED
== module Noggin::Job
--- Noggin::Job.cancel(String printer, Integer job_id)


=== Noggin::Job::CURRENT
=== Noggin::Job::ALL
== module Noggin::IPP
=== Noggin::IPP::GET_JOBS
