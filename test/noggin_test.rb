$: << File.join(File.dirname(__FILE__),'../lib')
require 'rubygems'
require 'noggin'
require 'glib2'
require 'test/unit'
require 'pp'

class CupsTest < Test::Unit::TestCase
  def setup

  end
  def test_destinations
    assert Noggin.destinations
  end
  def test_jobs
    assert Noggin.jobs(nil, 0, 0)
  end
  def test_cancel
    assert_raises RuntimeError do
      Noggin::Job.cancel("Fail", 99999)
    end
  end
  def test_print
    require 'prawn'

    fn = '../tmp/test.pdf'
    Prawn::Document.generate(fn) do |pdf|
      pdf.text("On The Noggin!")
    end
    dest = Noggin.destinations.first

    job_id = Noggin.printFile(dest['name'], fn, "Noggin-Test", {})

    assert job_id > 0
    Noggin::Job.cancel(dest['name'], job_id)
    
    jobs = Noggin.jobs(dest['name'], true, Noggin::WHICHJOBS_ALL)
    assert jobs.any? { |job| job['id'] == job_id && job['title'] == "Noggin-Test" && job['state'] == :cancelled }
    File.unlink(fn)
  end
end

