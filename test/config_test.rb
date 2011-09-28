# encoding: UTF-8

require 'vines/agent'
require 'minitest/autorun'

class ConfigTest < MiniTest::Unit::TestCase

  def teardown
    %w[data downloads].each do |dir|
      FileUtils.remove_dir(dir) if File.exist?(dir)
    end
  end

  def test_missing_host_raises
    assert_raises(RuntimeError) do
      Vines::Agent::Config.new do
        # missing domain
      end
    end
  end

  def test_multiple_domains_raises
    assert_raises(RuntimeError) do
      Vines::Agent::Config.new do
        domain 'wonderland.lit' do
          upstream 'localhost', 5222
          password 'secr3t'
        end
        domain 'verona.lit' do
          upstream 'localhost', 5222
          password 'secr3t'
        end
      end
    end
  end

  def test_configure
    config = Vines::Agent::Config.configure do
      domain 'wonderland.lit' do
        upstream 'localhost', 5222
        password 'secr3t'
      end
    end
    refute_nil config
    assert_same config, Vines::Agent::Config.instance
  end

  def test_default_download_directory
    config = Vines::Agent::Config.configure do
      domain 'wonderland.lit' do
        password 'secr3t'
      end
    end
    assert File.exist?('data')
  end

  def test_custom_download_directory
    config = Vines::Agent::Config.configure do
      domain 'wonderland.lit' do
        password 'secr3t'
        download 'downloads'
      end
    end
    assert File.exist?('downloads')
  end

  def test_missing_password_raises
    assert_raises(RuntimeError) do
      Vines::Agent::Config.new do
        domain 'wonderland.lit' do
          upstream 'localhost', 5222
        end
      end
    end
    assert_raises(RuntimeError) do
      Vines::Agent::Config.new do
        domain 'wonderland.lit' do
          upstream 'localhost', 5222
          password nil
        end
      end
    end
    assert_raises(RuntimeError) do
      Vines::Agent::Config.new do
        domain 'wonderland.lit' do
          upstream 'localhost', 5222
          password ''
        end
      end
    end
  end

  def test_invalid_log_level
    assert_raises(RuntimeError) do
      config = Vines::Agent::Config.new do
        log 'bogus'
        domain 'wonderland.lit' do
          upstream 'localhost', 5222
          password 'secr3t'
        end
      end
    end
  end

  def test_valid_log_level
    config = Vines::Agent::Config.new do
      log :error
      domain 'wonderland.lit' do
        upstream 'localhost', 5222
        password 'secr3t'
      end
    end
    assert_equal Logger::ERROR, Class.new.extend(Vines::Log).log.level
  end
end
