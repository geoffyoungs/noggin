%name noggin

%include cups/cups.h
%include cups/ipp.h
%include ruby.h
%include st.h
%lib cups

%{
inline VALUE as_string(const char *string);
int hash_to_cups_options_it(VALUE key, VALUE val, VALUE data);
static VALUE rb_ipp_value_entry(ipp_attribute_t* attr, int count);
static VALUE rb_ipp_value(ipp_attribute_t* attr);
VALUE job_state(ipp_jstate_t state);
static VALUE renew_subscription(int subscription_id, int duration);
static void debug_ipp(ipp_t *ipp);
static VALUE create_subscription(int duration, char *uri, char *printer);
static void cancel_subscription(int subscription_id);
static VALUE list_subscriptions(bool my_subscriptions);



inline VALUE as_string(const char *string)
{
  return string ? rb_str_new2(string) : Qnil;
}

static VALUE sym_aborted = Qnil;
static VALUE sym_cancelled = Qnil;
static VALUE sym_completed = Qnil;
static VALUE sym_held = Qnil;
static VALUE sym_pending = Qnil;
static VALUE sym_processing = Qnil;
static VALUE sym_stopped = Qnil;

#define SUBSCRIPTION_DURATION 3600
#define STATIC_STR(name) static VALUE str_##name = Qnil;
#define STATIC_STR_INIT(name) KEEP_ADD(str_##name = rb_str_new2(#name));
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

struct svp_it {
  int num_options;
  cups_option_t *options;
};

int hash_to_cups_options_it(VALUE key, VALUE val, VALUE data)
{
  struct svp_it *svp  = (struct svp_it *)data;
  svp->num_options = cupsAddOption(StringValuePtr(key), StringValuePtr(val), svp->num_options, &(svp->options));
  return ST_CONTINUE;
}

static VALUE rb_ipp_value_entry(ipp_attribute_t* attr, int count)
{
  const char *lang = NULL;
  char block[4096] = "";
 
  /*char block[4096] = "";
  ippAttributeString(attr, block, 4096);
  printf("%s: (0x%x) %s\n", ippGetName(attr), ippGetValueTag(attr), block);*/

  switch (ippGetValueTag(attr)) {
  case IPP_TAG_INTEGER:
  case IPP_TAG_JOB:
    return INT2NUM(ippGetInteger(attr, count));
  case IPP_TAG_ZERO:
    return INT2FIX(0);
  case IPP_TAG_RESERVED_STRING:
  case IPP_TAG_STRING:
  case IPP_TAG_SUBSCRIPTION:
  case IPP_TAG_TEXT:
  case IPP_TAG_NAME:
  case IPP_TAG_KEYWORD:
  case IPP_TAG_URI:
  case IPP_TAG_TEXTLANG:
  case IPP_TAG_NAMELANG:
  case IPP_TAG_LANGUAGE:
  case IPP_TAG_CHARSET:
  case IPP_TAG_MIMETYPE:
  case IPP_TAG_MEMBERNAME:
  case IPP_TAG_URISCHEME:
    return as_string(ippGetString(attr, count, &lang));
  case IPP_TAG_BOOLEAN:
    return ippGetBoolean(attr, count) ? Qtrue : Qfalse;
  case IPP_TAG_CUPS_INVALID:
    return Qnil;
/* Are these just groups tags? */
  case IPP_TAG_OPERATION:
  case IPP_TAG_END:
  case IPP_TAG_PRINTER:
  case IPP_TAG_UNSUPPORTED_GROUP:
  case IPP_TAG_EVENT_NOTIFICATION:
  case IPP_TAG_RESOURCE:
  case IPP_TAG_DOCUMENT:
  case IPP_TAG_UNSUPPORTED_VALUE:
  case IPP_TAG_DEFAULT:
  case IPP_TAG_UNKNOWN:
  case IPP_TAG_NOVALUE:
  case IPP_TAG_NOTSETTABLE:
  case IPP_TAG_DELETEATTR:
  case IPP_TAG_ADMINDEFINE:
  case IPP_TAG_ENUM:
  case IPP_TAG_DATE:
  case IPP_TAG_RESOLUTION:
  case IPP_TAG_RANGE:
  case IPP_TAG_BEGIN_COLLECTION:
  case IPP_TAG_END_COLLECTION:
  case IPP_TAG_EXTENSION:
  case IPP_TAG_MASK:
  case IPP_TAG_COPY:
  default:
    ippAttributeString(attr, block, 4096);
    printf("[UNSUPPORTED] %s: (%i) %s\n", ippGetName(attr), ippGetValueTag(attr), block);

    return Qnil;
  }
}

static VALUE rb_ipp_value(ipp_attribute_t* attr)
{
  int num = ippGetCount(attr), i = 0;
  VALUE val = Qnil;

  switch (num)  {
    case 0:
      return Qnil;
    case 1:
      return rb_ipp_value_entry(attr, 0);
    default:
      val = rb_ary_new();
      for(i = 0; i < num; i++) {
        rb_ary_push(val, rb_ipp_value_entry(attr, i));
      }
      return val;
  }
}


VALUE job_state(ipp_jstate_t state)
{
  switch(state)
  {
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
    default:
      return INT2FIX(state);
   }
}

static VALUE renew_subscription(int subscription_id, int duration)
{
  http_t *http;
  ipp_t *request;

  if ((http = httpConnectEncrypt(cupsServer(), ippPort(), cupsEncryption ())) == NULL) {
    return Qnil;
  }

  request = ippNewRequest (IPP_RENEW_SUBSCRIPTION);
  ippAddString (request, IPP_TAG_OPERATION, IPP_TAG_URI,
               "printer-uri", NULL, "/");
  ippAddString (request, IPP_TAG_OPERATION, IPP_TAG_NAME,
               "requesting-user-name", NULL, cupsUser());
  ippAddInteger (request, IPP_TAG_OPERATION, IPP_TAG_INTEGER,
                "notify-subscription-id", subscription_id);
  ippAddInteger (request, IPP_TAG_SUBSCRIPTION, IPP_TAG_INTEGER,
                "notify-lease-duration", duration);
  ippDelete (cupsDoRequest (http, request, "/"));

  httpClose(http);

  return INT2NUM(subscription_id);
}

static void debug_ipp(ipp_t *ipp)
{
  char block[4096] = "";
  ipp_attribute_t *attr = NULL;
  
   for (attr = ippFirstAttribute(ipp); attr; attr = ippNextAttribute(ipp)) {
    ippAttributeString(attr, block, 4096);
    printf("[DEBUG] %s: (%i) %s\n", ippGetName(attr), ippGetValueTag(attr), block);
  }
  
}

static VALUE create_subscription(int duration, char *uri, char *printer)
{
  ipp_attribute_t *attr = NULL;
  http_t *http;
  ipp_t *request;
  ipp_t *response;
  VALUE subscription_id = 0;
  int num_events = 7;
  static const char * const events[] = {
    "job-created",
    "job-completed",
    "job-state-changed",
    "job-state",
    "printer-added",
    "printer-deleted",
    "printer-state-changed"
  };

  if ((http = httpConnectEncrypt(cupsServer(), ippPort(), cupsEncryption())) == NULL) {
    return Qnil;
  }

  request = ippNewRequest (IPP_CREATE_PRINTER_SUBSCRIPTION);
  ippAddString(request, IPP_TAG_OPERATION, IPP_TAG_URI,
                "printer-uri", NULL, printer);
  ippAddString(request, IPP_TAG_OPERATION, IPP_TAG_NAME,
                "requesting-user-name", NULL, cupsUser ());
  ippAddStrings(request, IPP_TAG_SUBSCRIPTION, IPP_TAG_KEYWORD,
                 "notify-events", num_events, NULL, events);
  ippAddString(request, IPP_TAG_SUBSCRIPTION, IPP_TAG_KEYWORD,
                "notify-pull-method", NULL, "ippget");
  ippAddString(request, IPP_TAG_SUBSCRIPTION, IPP_TAG_URI,
                "notify-recipient-uri", NULL, uri);
  ippAddInteger(request, IPP_TAG_SUBSCRIPTION, IPP_TAG_INTEGER,
                 "notify-lease-duration", duration);
  response = cupsDoRequest (http, request, "/");

  if (response != NULL && ippGetStatusCode(response) <= IPP_OK_CONFLICT) {
    /*debug_ipp(response);*/
    ippFirstAttribute(response);

    if ((attr = ippFindAttribute(response, "notify-subscription-id", IPP_TAG_INTEGER)) != NULL) {
      subscription_id = INT2NUM(ippGetInteger(attr, 0));
    } else {
      subscription_id = Qnil;
    }
  }

  if (response) {
    ippDelete(response);
  }

  httpClose (http);

  return subscription_id;
}

static void cancel_subscription(int subscription_id)
{
  http_t *http;
  ipp_t *request;

  if (subscription_id >= 0 &&
       ((http = httpConnectEncrypt(cupsServer(), ippPort(), cupsEncryption())) != NULL)) {

    request = ippNewRequest(IPP_CANCEL_SUBSCRIPTION);
    ippAddString(request, IPP_TAG_OPERATION, IPP_TAG_URI,
                 "printer-uri", NULL, "/");
    ippAddString(request, IPP_TAG_OPERATION, IPP_TAG_NAME,
                 "requesting-user-name", NULL, cupsUser());
    ippAddInteger(request, IPP_TAG_OPERATION, IPP_TAG_INTEGER,
                  "notify-subscription-id", subscription_id);
    ippDelete(cupsDoRequest(http, request, "/"));

    httpClose(http);
  }
}

static VALUE list_subscriptions(bool my_subscriptions)
{
  ipp_attribute_t *attr = NULL;
  http_t *http;
  ipp_t *request;
  ipp_t *response;
  VALUE ary = rb_ary_new();
  static const char * const req_attr[] = {
    "all"
  };

  if ((http = httpConnectEncrypt(cupsServer(), ippPort(), cupsEncryption ())) == NULL) {
    return Qnil;
  }

  request = ippNewRequest (IPP_GET_SUBSCRIPTIONS);
  ippAddString(request, IPP_TAG_OPERATION, IPP_TAG_URI,
                "printer-uri", NULL, "/");
  ippAddString(request, IPP_TAG_OPERATION, IPP_TAG_NAME,
                "requesting-user-name", NULL, cupsUser ());
  ippAddStrings(request, IPP_TAG_SUBSCRIPTION, IPP_TAG_KEYWORD,
                 "requested-attributes", 1, NULL, req_attr);
  ippAddBoolean(request, IPP_TAG_SUBSCRIPTION, "my-subscriptions",
                 my_subscriptions);
  response = cupsDoRequest (http, request, "/");

  if (response == NULL) {
    goto out;
  }

  if (ippGetStatusCode(response) <= IPP_OK_CONFLICT) {
    const char *name;
    VALUE hash = rb_hash_new();

    attr = ippFirstAttribute(response);
    ippNextAttribute(response);
    ippNextAttribute(response);

    rb_ary_push(ary, hash);

    for (; attr != NULL; attr = ippNextAttribute(response)) {
      name = ippGetName(attr);

      if (name == NULL) {
        hash = rb_hash_new();
        rb_ary_push(ary, hash);
      } else {
        rb_hash_aset(hash, as_string(name), rb_ipp_value(attr));
        /*{ char block[4096] = ""; puts(ippGetName(attr));
        if (ippAttributeString(attr, block, 4096) > 0) {
          puts(block);
        }}*/
      }
    }
  }

  ippDelete(response);

out:
  httpClose (http);

  return ary;
}

%}

%post_init{
  KEEP_DEL(Qnil);
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
        rb_hash_aset(options, as_string((dest->options[j].name)), as_string((dest->options[j].value)));
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

  module Subscription
    def self.create(int duration=0, char *notify_uri=(char*)"dbus://", char *printer=(char*)"/")
      return create_subscription(duration, notify_uri, printer);
    end
    def self.renew(int id, int duration=0)
      return renew_subscription(id, duration);
    end
    def self.cancel(int id)
      cancel_subscription(id);
    end
    def self.list(bool my_subscriptions=1)
      return list_subscriptions(my_subscriptions);
    end
  end
end
