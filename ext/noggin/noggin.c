#pragma GCC diagnostic ignored "-Wunused-but-set-variable"
/* Includes */
#include <ruby.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "cups/cups.h"
#include "cups/ipp.h"
#include "ruby.h"
#include "st.h"

/* Setup types */
/* Try not to clash with other definitions of bool... */
typedef int rubber_bool;
#define bool rubber_bool

/* Prototypes */
static VALUE mNoggin;
static VALUE
Noggin_CLASS_destinations(VALUE self);
static VALUE
Noggin_CLASS_jobs(VALUE self, VALUE printer, VALUE __v_mine, VALUE __v_whichjobs);
static VALUE
Noggin_CLASS_ippRequest(VALUE self, VALUE __v_operation, VALUE request_attributes);
static VALUE
Noggin_CLASS_printFile(int __p_argc, VALUE *__p_argv, VALUE self);
static VALUE mJob;
static VALUE
Job_CLASS_cancel(VALUE self, VALUE __v_printer, VALUE __v_job_id);
static VALUE mIPP;
static VALUE cIppRequest;
static VALUE _gcpool_Keep = Qnil;
static void __gcpool_Keep_add(VALUE val);
static void __gcpool_Keep_del(VALUE val);
#define KEEP_ADD(val) __gcpool_Keep_add(val)
#define KEEP_DEL(val) __gcpool_Keep_del(val)

/* Inline C code */


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


/* Code */
static VALUE
Noggin_CLASS_destinations(VALUE self)
{
  VALUE __p_retval = Qnil;

#line 161 "/home/geoff/Projects/noggin/ext/noggin/noggin.cr"

  do {
  VALUE  list  =
 Qnil;
  cups_dest_t * dests  ;
 int num_dests = cupsGetDests(&dests);
  cups_dest_t * dest  ;
 int  i  ;
 const char * value  ;
 int  j  ;
 list = rb_ary_new2(num_dests);
  for (i = num_dests, dest = dests;
  i > 0;
  i --, dest ++) { VALUE  hash  =
 rb_hash_new(), options = rb_hash_new();
  rb_hash_aset(hash, str_name, as_string(dest->name));
  rb_hash_aset(hash, str_instance, as_string(dest->instance));
  rb_hash_aset(hash, str_is_default, INT2NUM(dest->is_default));
  rb_hash_aset(hash, str_options, options);
  for (j = 0;
  j < dest->num_options;
  j++) { rb_hash_aset(options, as_string(dest->options[j].name), as_string(dest->options[j].value));
  } rb_ary_push(list, hash);
  } cupsFreeDests(num_dests, dests);
  do { __p_retval = list; goto out; } while(0);

  } while(0);

out:
  return __p_retval;
}

static VALUE
Noggin_CLASS_jobs(VALUE self, VALUE printer, VALUE __v_mine, VALUE __v_whichjobs)
{
  VALUE __p_retval = Qnil;
  bool mine; bool __orig_mine;
  int whichjobs; int __orig_whichjobs;
  if (! ((TYPE(printer) == T_NIL) || (TYPE(printer) == T_STRING)) )
    rb_raise(rb_eArgError, "printer argument must be one of Nil, String");
  __orig_mine = mine = RTEST(__v_mine);
  __orig_whichjobs = whichjobs = NUM2INT(__v_whichjobs);

#line 192 "/home/geoff/Projects/noggin/ext/noggin/noggin.cr"

  do {
  VALUE  list  =
 Qnil;
  cups_job_t *jobs, *job;
  int num_jobs, i;
  num_jobs = cupsGetJobs(&jobs, (NIL_P(printer) ? (char*)0 : RSTRING_PTR(printer)), (mine ? 1 : 0), whichjobs);
  list = rb_ary_new2(num_jobs);
  for (i = num_jobs, job = jobs;
  i > 0;
  i --, job ++) { VALUE  hash  =
 rb_hash_new();
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
  } cupsFreeJobs(num_jobs, jobs);
  do { __p_retval = list; goto out; } while(0);

  } while(0);

out:
  return __p_retval;
}

static VALUE
Noggin_CLASS_ippRequest(VALUE self, VALUE __v_operation, VALUE request_attributes)
{
  VALUE __p_retval = Qnil;
  int operation; int __orig_operation;
  __orig_operation = operation = NUM2INT(__v_operation);

#line 227 "/home/geoff/Projects/noggin/ext/noggin/noggin.cr"

  do {
  VALUE  resp  =
 Qnil;
  ipp_t * request  =
 NULL , *response = NULL;
  ipp_attribute_t * attr  =
 NULL;
  request = ippNewRequest(operation);
  rb_hash_foreach(request_attributes, add_to_request_iterator, (VALUE)request);
  response = cupsDoRequest(CUPS_HTTP_DEFAULT, request, "/");
  resp = rb_hash_new();
  for (attr = ippFirstAttribute(response);
  attr != NULL;
  attr = ippNextAttribute(response)) { rb_hash_aset(resp, as_string(ippGetName(attr)), rb_ipp_value(attr));
  } do { __p_retval = resp; goto out; } while(0);

  } while(0);

out:
  return __p_retval;
}

static VALUE
Noggin_CLASS_printFile(int __p_argc, VALUE *__p_argv, VALUE self)
{
  VALUE __p_retval = Qnil;
  VALUE __v_destinationName = Qnil;
  char * destinationName; char * __orig_destinationName;
  VALUE __v_fileName = Qnil;
  char * fileName; char * __orig_fileName;
  VALUE __v_title = Qnil;
  char * title; char * __orig_title;
  VALUE options = Qnil;

  /* Scan arguments */
  rb_scan_args(__p_argc, __p_argv, "31",&__v_destinationName, &__v_fileName, &__v_title, &options);

  /* Set defaults */
  __orig_destinationName = destinationName = ( NIL_P(__v_destinationName) ? NULL : StringValuePtr(__v_destinationName) );

  __orig_fileName = fileName = ( NIL_P(__v_fileName) ? NULL : StringValuePtr(__v_fileName) );

  __orig_title = title = ( NIL_P(__v_title) ? NULL : StringValuePtr(__v_title) );

  if (__p_argc <= 3)
    options = Qnil;
  else
  if (! ((TYPE(options) == T_HASH) || (TYPE(options) == T_NIL)) )
    rb_raise(rb_eArgError, "options argument must be one of Hash, Nil");


#line 246 "/home/geoff/Projects/noggin/ext/noggin/noggin.cr"

  do {
  struct svp_it  info  =
 {0, NULL};
  int job_id = -1;
  if (TYPE(options) == T_HASH) { rb_hash_foreach(options, hash_to_cups_options_it, (VALUE)&info);
  } job_id = cupsPrintFile(destinationName, fileName, title, info.num_options, info.options);
  if (info.options) { cupsFreeOptions(info.num_options, info.options);
  } do { __p_retval =  INT2NUM(job_id); goto out; } while(0);

  } while(0);

out:
  return __p_retval;
}

static VALUE
Job_CLASS_cancel(VALUE self, VALUE __v_printer, VALUE __v_job_id)
{
  char * printer; char * __orig_printer;
  int job_id; int __orig_job_id;
  __orig_printer = printer = ( NIL_P(__v_printer) ? NULL : StringValuePtr(__v_printer) );
  __orig_job_id = job_id = NUM2INT(__v_job_id);

#line 152 "/home/geoff/Projects/noggin/ext/noggin/noggin.cr"
  if (cupsCancelJob(printer, job_id) == 0) { rb_raise(rb_eRuntimeError, "CUPS Error: %d - %s", cupsLastError(), cupsLastErrorString());
  }
  return Qnil;
}

static void __gcpool_Keep_add(VALUE val)
    {
      if (_gcpool_Keep == Qnil)
      {
        _gcpool_Keep = rb_ary_new3(1, val);
      }
      else
      {
        rb_ary_push(_gcpool_Keep, val);
      }
    }
    
    static void __gcpool_Keep_del(VALUE val)
    {
      if (_gcpool_Keep == Qnil)
      {
        rb_warn("Trying to remove object from empty GC queue Keep");
        return;
      }
      rb_ary_delete(_gcpool_Keep, val);
      // If nothing is referenced, don't keep an empty array in the pool...
      if (RARRAY_LEN(_gcpool_Keep) == 0)
        _gcpool_Keep = Qnil;
    }
    
/* Init */
void
Init_noggin(void)
{
  mNoggin = rb_define_module("Noggin");
  rb_define_singleton_method(mNoggin, "destinations", Noggin_CLASS_destinations, 0);
  rb_define_singleton_method(mNoggin, "jobs", Noggin_CLASS_jobs, 3);
  rb_define_singleton_method(mNoggin, "ippRequest", Noggin_CLASS_ippRequest, 2);
  rb_define_singleton_method(mNoggin, "printFile", Noggin_CLASS_printFile, -1);
    rb_define_const(mNoggin, "WHICHJOBS_ALL", INT2NUM(CUPS_WHICHJOBS_ALL));
    rb_define_const(mNoggin, "WHICHJOBS_ACTIVE", INT2NUM(CUPS_WHICHJOBS_ACTIVE));
    rb_define_const(mNoggin, "WHICHJOBS_COMPLETED", INT2NUM(CUPS_WHICHJOBS_COMPLETED));
  mJob = rb_define_module_under(mNoggin, "Job");
  rb_define_singleton_method(mJob, "cancel", Job_CLASS_cancel, 2);
    rb_define_const(mJob, "CURRENT", INT2NUM(CUPS_JOBID_CURRENT));
    rb_define_const(mJob, "ALL", INT2NUM(CUPS_JOBID_ALL));
  mIPP = rb_define_module_under(mNoggin, "IPP");
    rb_define_const(mIPP, "GET_JOBS", INT2NUM(IPP_GET_JOBS));
  cIppRequest = rb_define_class_under(mNoggin, "IppRequest", rb_cObject);
rb_gc_register_address(&_gcpool_Keep);

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
}
