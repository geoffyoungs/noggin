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
  def testcancel
    assert_raises RuntimeError do
      Noggin::Job.cancel("Fail", 99999)
    end
  end
end

