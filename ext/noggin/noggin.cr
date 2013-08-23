%name noggin

%include cups/cups.h
%include cups/ipp.h
%include ruby.h
%include st.h
%lib cups

%{

VALUE inline as_string(const char *string) { return string ? rb_str_new2(string) : Qnil;  }

#define TO_STRING(v) ((v) ? rb_str_new2((v)) : Qnil)

VALUE job_state(ipp_jstate_t state) {
  switch(state) {
    case IPP_JOB_ABORTED:
      return ID2SYM(rb_intern("aborted"));
    case IPP_JOB_CANCELED:
      return ID2SYM(rb_intern("cancelled"));
    case IPP_JOB_COMPLETED:
      return ID2SYM(rb_intern("completed"));
    case IPP_JOB_HELD:
      return ID2SYM(rb_intern("held"));
    case IPP_JOB_PENDING:
      return ID2SYM(rb_intern("pending"));
    case IPP_JOB_PROCESSING:
      return ID2SYM(rb_intern("processing"));
    case IPP_JOB_STOPPED:
      return ID2SYM(rb_intern("stopped"));
  }
}

VALUE rb_ipp_value(ipp_attribute_t* attr) {
  char *lang = NULL;
  switch (ippGetValueTag(attr)) {
  case IPP_TAG_INTEGER:
    return INT2NUM(ippGetInteger(attr, 0));
  case IPP_TAG_TEXT:
  case IPP_TAG_NAME:
  case IPP_TAG_URI:
  case IPP_TAG_URISCHEME:
    return as_string(ippGetString(attr, 0, &lang)); 
  case IPP_TAG_BOOLEAN:
    return ippGetBoolean(attr, 0) ? Qtrue : Qfalse;
  }
  return Qnil;

}
int add_to_request_iterator(VALUE key, VALUE val, VALUE data) {
  ipp_t *request = (ipp_t*) data;
  char *name = RSTRING_PTR(key);

  switch(TYPE(val)) {
    case T_FIXNUM:
      ippAddInteger(request, IPP_TAG_OPERATION, IPP_TAG_INTEGER, name, NUM2INT(val));
      break;
    case T_STRING:
      ippAddString(request, IPP_TAG_OPERATION, IPP_TAG_NAME, name, NULL, RSTRING_PTR(val));
      break;
    case T_TRUE: 
    case T_FALSE:
      ippAddBoolean(request, IPP_TAG_OPERATION, name, (val) ? 1 : 0);
      break;
  }
  return ST_CONTINUE;
}

%}

%pre_init{
%}

%map ruby - (char *) => (VALUE): rb_str_new2(#0)
%map string - (VALUE) => (char *): RSTRING_PTR(%%)

%option glib=no

module Noggin
  int WHICHJOBS_ALL = CUPS_WHICHJOBS_ALL
  int WHICHJOBS_ACTIVE = CUPS_WHICHJOBS_ACTIVE
  int WHICHJOBS_COMPLETED = CUPS_WHICHJOBS_COMPLETED

  module Job
    int CURRENT = CUPS_JOBID_CURRENT
    int ALL = CUPS_JOBID_ALL
    def int:self.cancel(char * printer, int job_id)
      if (cupsCancelJob(printer, job_id) == 0) {
        rb_raise(rb_eRuntimeError, "CUPS Error: %d - %s", cupsLastError(), cupsLastErrorString());
      }
    end
  end
  module IPP
    int GET_JOBS = IPP_GET_JOBS
  end
  def self.destinations
    VALUE list = Qnil;
    cups_dest_t *dests;
    int num_dests = cupsGetDests(&dests);
    cups_dest_t *dest;
    int i;
    const char *value;
    int j;

    list = rb_ary_new2(num_dests);
    for (i = num_dests, dest = dests; i > 0; i --, dest ++) 
    {
      VALUE hash = rb_hash_new(), options = rb_hash_new();
      rb_hash_aset(hash, rb_str_new2("name"), as_string(dest->name));
      rb_hash_aset(hash, rb_str_new2("instance"), as_string(dest->instance));
      rb_hash_aset(hash, rb_str_new2("is_default"), INT2NUM(dest->is_default));
      rb_hash_aset(hash, rb_str_new2("options"), options);

      for (j = 0; j < dest->num_options; j++) {
        rb_hash_aset(options, as_string(dest->options[j].name), as_string(dest->options[j].value));
      }
      

      rb_ary_push(list, hash);
    }

    cupsFreeDests(num_dests, dests);

    return list;
  end

  def self.jobs(T_NIL|T_STRING printer, bool mine, int whichjobs) 
    VALUE list = Qnil;
    cups_job_t *jobs, *job;
    int num_jobs, i;
   
    num_jobs = cupsGetJobs(&jobs, (NIL_P(printer) ? (char*)0 : RSTRING_PTR(printer)), (mine ? 1 : 0), whichjobs);

    list = rb_ary_new2(num_jobs);
    for (i = num_jobs, job = jobs; i > 0; i --, job ++) 
    {
      VALUE hash = rb_hash_new();
      rb_hash_aset(hash, rb_str_new2("completed_time"), rb_time_new(job->completed_time, 0));
      rb_hash_aset(hash, rb_str_new2("creation_time"), rb_time_new(job->creation_time, 0));
      rb_hash_aset(hash, rb_str_new2("dest"), as_string(job->dest));
      rb_hash_aset(hash, rb_str_new2("format"), as_string(job->format));
      rb_hash_aset(hash, rb_str_new2("id"), INT2NUM(job->id));
      rb_hash_aset(hash, rb_str_new2("priority"), INT2NUM(job->priority));
      rb_hash_aset(hash, rb_str_new2("processing_time"), rb_time_new(job->processing_time, 0));
      rb_hash_aset(hash, rb_str_new2("size"), INT2NUM(job->size));
      rb_hash_aset(hash, rb_str_new2("title"), as_string(job->title));
      rb_hash_aset(hash, rb_str_new2("user"), as_string(job->user));
      rb_hash_aset(hash, rb_str_new2("state"), job_state(job->state));

      rb_ary_push(list, hash);
    }

    cupsFreeJobs(num_jobs, jobs);

    return list;
  end

  def self.ippRequest(int operation, VALUE request_attributes)
    VALUE resp = Qnil;
    ipp_t *request = NULL , *response = NULL;
    ipp_attribute_t *attr = NULL;

    request = ippNewRequest(operation);
    rb_hash_foreach(request_attributes, add_to_request_iterator, (VALUE)request);

    response = cupsDoRequest(CUPS_HTTP_DEFAULT, request, "/");
     
    resp = rb_hash_new();

    for (attr = ippFirstAttribute(response); attr != NULL; attr = ippNextAttribute(response)) {
      rb_hash_aset(resp, as_string(ippGetName(attr)), rb_ipp_value(attr));
    }

    return resp;
  end
end
