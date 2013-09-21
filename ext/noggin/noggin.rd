= module Noggin
--- Noggin.destinations()


--- Noggin.jobs(String printer, Boolean mine, Integer whichjobs)


--- Noggin.printFile(String destinationName, String fileName, String title, Hash options)


== Noggin::WHICHJOBS_ALL
== Noggin::WHICHJOBS_ACTIVE
== Noggin::WHICHJOBS_COMPLETED
== module Noggin::Job
--- Noggin::Job.cancel(String printer, Integer job_id)


=== Noggin::Job::CURRENT
=== Noggin::Job::ALL
== module Noggin::IPP
=== Noggin::IPP::GET_JOBS
== module Noggin::Subscription
--- Noggin::Subscription.create(Integer duration, String notify_uri, String printer)


--- Noggin::Subscription.renew(Integer id, Integer duration)


--- Noggin::Subscription.cancel(Integer id)


--- Noggin::Subscription.list(Boolean my_subscriptions)


