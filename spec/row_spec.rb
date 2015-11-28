require 'spec_helper'

describe Unresponsys::Row do

  before :each do
    Unresponsys::Client.new(username: ENV['R_USER'], password: ENV['R_PASS'], debug: false)
    allow_any_instance_of(Unresponsys::Client).to receive(:authenticate).and_return(true)
  end

  context 'when an existing row' do

  end

  context 'when a new row' do
    before :each do
      folder  = Unresponsys::Folder.find('TestData')
      table   = folder.tables.find('TestTable')
      @row    = table.rows.new(1)

      # at least one field must be set
      @row.title = 'My Title'
    end

    describe '#save' do
      it 'posts to Responsys' do
        VCR.use_cassette('save_new_row') do
          expect(Unresponsys::Client).to receive(:post).and_call_original
          @row.save
        end
      end

      it 'returns true' do
        VCR.use_cassette('save_new_row') do
          expect(@row.save).to eq(true)
        end
      end
    end
  end

end