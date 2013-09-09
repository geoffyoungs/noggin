%name noggin

%include cups/cups.h
%include cups/ipp.h
%include ruby.h
%include st.h
%lib cups

%{

VALUE inline as_string(const char *string) { return string ? rb_str_new2(string) : Qnil;  }

#define TO_STRING(v) ((v) ? rb_str_new2((v)) : Qnil)

static VALUE sym_aborted = Qnil;
static VALUE sym_cancelled = Qnil;
static VALUE sym_completed = Qnil;
static VALUE sym_held = Qnil;
static VALUE sym_pending = Qnil;
static VALUE sym_processing = Qnil;
static VALUE sym_stopped = Qnil;

#define STATIC_STR(name) static VALUE str_##name = Qnil;
#define STATIC_STR_INIT(name) KEEP_ADD(str_##name = rb_str_new2(#name)); rb_obj_freeze(str_##name);
STATIC_STR(completed_time);
STATIC_STR(creation_time);
STATIC_STR(dest);
STATIC_STR(format);
STATIC_STR(id);
STATIC_STR(priority);
STATIC_STR(processing_time);
STATIC_STR(size);
STATIC_STR(title);
STATIC_STR(user);
STATIC_STR(state);

STATIC_STR(name);
STATIC_STR(instance);
STATIC_STR(is_default);
STATIC_STR(options);

VALUE job_state(ipp_jstate_t state) {
  switch(state) {
    case IPP_JOB_ABORTED:
      return sym_aborted;
    case IPP_JOB_CANCELED:
      return sym_cancelled;
    case IPP_JOB_COMPLETED:
      return sym_completed;
    case IPP_JOB_HELD:
      return sym_held;
    case IPP_JOB_PENDING:
      return sym_pending;
    case IPP_JOB_PROCESSING:
      return sym_processing;
    case IPP_JOB_STOPPED:
      return sym_stopped;
  }
  return INT2FIX(state);
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

struct svp_it {
  int num_options;
  cups_option_t *options;
};

int hash_to_cups_options_it(VALUE key, VALUE val, VALUE data) {
  struct svp_it *svp  = (struct svp_it *)data;

  svp->num_options = cupsAddOption(StringValuePtr(key), StringValuePtr(val), svp->num_options, &(svp->options));

  return ST_CONTINUE;
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

%post_init{
  KEEP_ADD(sym_cancelled = ID2SYM(rb_intern("cancelled")));
  KEEP_ADD(sym_completed = ID2SYM(rb_intern("completed")));
  KEEP_ADD(sym_held = ID2SYM(rb_intern("held")));
  KEEP_ADD(sym_pending = ID2SYM(rb_intern("pending")));
  KEEP_ADD(sym_processing = ID2SYM(rb_intern("processing")));
  KEEP_ADD(sym_stopped = ID2SYM(rb_intern("stopped")));

  STATIC_STR_INIT(completed_time);
  STATIC_STR_INIT(creation_time);
  STATIC_STR_INIT(dest);
  STATIC_STR_INIT(format);
  STATIC_STR_INIT(id);
  STATIC_STR_INIT(priority);
  STATIC_STR_INIT(processing_time);
  STATIC_STR_INIT(size);
  STATIC_STR_INIT(title);
  STATIC_STR_INIT(user);
  STATIC_STR_INIT(state);

  STATIC_STR_INIT(name);
  STATIC_STR_INIT(instance);
  STATIC_STR_INIT(is_default);
  STATIC_STR_INIT(options);
%}

%map ruby - (char *) => (VALUE): rb_str_new2(#0)
%map string - (VALUE) => (char *): RSTRING_PTR(%%)

%option glib=no

module Noggin
  int WHICHJOBS_ALL = CUPS_WHICHJOBS_ALL
  int WHICHJOBS_ACTIVE = CUPS_WHICHJOBS_ACTIVE
  int WHICHJOBS_COMPLETED = CUPS_WHICHJOBS_COMPLETED

  gcpool Keep
  module Job
    int CURRENT = CUPS_JOBID_CURRENT
    int ALL = CUPS_JOBID_ALL
    def self.cancel(char * printer, int job_id)
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
      rb_hash_aset(hash, str_name, as_string(dest->name));
      rb_hash_aset(hash, str_instance, as_string(dest->instance));
      rb_hash_aset(hash, str_is_default, INT2NUM(dest->is_default));
      rb_hash_aset(hash, str_options, options);

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
      rb_hash_aset(hash, str_completed_time, rb_time_new(job->completed_time, 0));
      rb_hash_aset(hash, str_creation_time, rb_time_new(job->creation_time, 0));
      rb_hash_aset(hash, str_dest, as_string(job->dest));
      rb_hash_aset(hash, str_format, as_string(job->format));
      rb_hash_aset(hash, str_id, INT2NUM(job->id));
      rb_hash_aset(hash, str_priority, INT2NUM(job->priority));
      rb_hash_aset(hash, str_processing_time, rb_time_new(job->processing_time, 0));
      rb_hash_aset(hash, str_size, INT2NUM(job->size));
      rb_hash_aset(hash, str_title, as_string(job->title));
      rb_hash_aset(hash, str_user, as_string(job->user));
      rb_hash_aset(hash, str_state, job_state(job->state));

      rb_ary_push(list, hash);
    }

    cupsFreeJobs(num_jobs, jobs);

    return list;
  end

  class IppRequest

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

  def int:self.printFile(char *destinationName, char *fileName, char *title, T_HASH|T_NIL options = Qnil)
    struct svp_it info = {0, NULL};
    int job_id = -1;

    if (TYPE(options) == T_HASH) {
      rb_hash_foreach(options, hash_to_cups_options_it, (VALUE)&info);
    }

    job_id = cupsPrintFile(destinationName, fileName, title, info.num_options, info.options);

    if (info.options) {
      cupsFreeOptions(info.num_options, info.options);
    }

    return job_id;
  end
end
