require 'spec_helper'
require 'hashie'

describe Service::Campfire do
  before do
    @config = { :subdomain => "crashlytics",
                      :room => "crashlytics-test",
                      :api_token => "376136523ffbc6b82c289b5831681db8c1835e65" }
  end

  it 'should have a title' do
    expect(Service::Campfire.title).to eq('Campfire')
  end

  describe 'find_campfire_room' do
    before do
      @service = Service::Campfire.new('verification', {})
    end

    it "should find and return Campfire room" do
      campfire = double(Tinder::Campfire)
      expect(Tinder::Campfire).to receive(:new).with(@config[:subdomain], :token => @config[:api_token]).and_return(campfire)
      expect(campfire).to receive(:find_room_by_name).with(@config[:room])

      proc = Proc.new do |param|
        find_campfire_room(param)
      end

      @service.instance_exec @config, &proc
    end
  end

  describe 'receive_verification' do
    before do
      @service = Service::Campfire.new('verification', {})
      @payload = {}
    end

    it 'should succeed upon successful api response' do
      expect(@service).to receive(:find_campfire_room).with(@config).and_return(double(:name => @config[:room]))

      resp = @service.receive_verification(@config, @payload)
      expect(resp).to eq([true, 'Successfully verified Campfire settings'])
    end

    it 'should fail upon unsuccessful api response' do
      expect(@service).to receive(:find_campfire_room).with(@config).and_return(nil)

      resp = @service.receive_verification(@config, @payload)
      expect(resp).to eq([false, "Oops! Can not find #{@config[:room]} room. Please check your settings."])
    end
  end

  describe 'receive_issue_impact_change' do
    before do
      @service = Service::Campfire.new('issue_impact_change', {})
      @payload = {
        :title => 'foo title',
        :impact_level => 1,
        :impacted_devices_count => 1,
        :crashes_count => 1,
        :app => {
          :name => 'foo name',
          :bundle_identifier => 'foo.bar.baz'
        },
        :url => "http://foo.com/bar"
      }

      @room = double(:name =>@config[:room])
      expect(@service).to receive(:find_campfire_room).and_return(@room)
    end

    it 'should succeed upon successful api response' do
      expect(@room).to receive(:speak).and_return(Hashie::Mash.new(:message => { :id => 766665427 }))
      resp = @service.receive_issue_impact_change(@config, @payload)
      expect(resp).to eq(:campfire_message_id => 766665427)
    end

    it 'should fail upon unsuccessful api response' do
      expect(@room).to receive(:speak).and_return(nil)
      expect { @service.receive_issue_impact_change(@config, @payload) }.to raise_error
    end
  end
end
