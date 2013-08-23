noggin
======

Cups API wrapper for ruby

Noggin.destinations -> 
  [
    {
      'name' => printerName,
      'instance' => instanceName,
      'is_default' => is_default,
      'options' => { ... },
    }
  ]


Noggin::WHICHJOBS_ALL
Noggin::WHICHJOBS_ACTIVE
Noggin::WHICHJOBS_COMPLETED

Noggin.jobs(printerName, bool justMine, int whichJobs) ->
  [
    {
      'id' => id, 
      'dest' => printerName,
      'completed_time' => , 
      'creation_time'  
      'format' => mimetype,
      'priority' => int,
      'processing_time' => time,
      'size' => size in kb,
      'user' => owner,
      'state' => one of :aborted, :cancelled, :completed, :held, :pending, :processing, :stopped
    }
  ]   


Noggin::Job.cancel(printer, job_id)

