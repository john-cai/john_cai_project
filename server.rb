require 'sinatra'
require 'haml'
require 'json'

get '/' do
  content_type 'text/plain'
  File.read(File.expand_path(File.dirname(__FILE__)) + '/README.md')
end

get '/:ledger_name' do
  data_file = File.read(File.expand_path(File.dirname(__FILE__)) + "/data/#{params[:ledger_name]}.json")
  @ledger_data = JSON.parse(data_file)

  clean_ledger(@ledger_data)

  raise 'No data' unless @ledger_data
  haml :ledger

end


def clean_ledger(ledger_data)
  # sort by date
  ledger_data.sort_by! { |ledger| ledger['date'] }

  # remove duplicates
  ledger_data.uniq! { |ledger| ledger['activity_id'] }
  # add mystery transactions
  ledger_data.each_with_index do |ledger, index|
    if index == ledger_data.length() - 1
      next
    end

    expected_balance = ledger['balance'] + ledger_data[index+1]['amount']
    if expected_balance != ledger_data[index+1]['balance']
      difference = ledger_data[index+1]['balance'] - expected_balance 

      amount = difference
      balance = difference + ledger['balance']

      # look for this transaction in the rest of the data
      #
      found_out_of_order_transaction = false
      ledger_data[index+1..ledger_data.size()].each_with_index do |l, i|
        if l['amount'].to_f == amount and l['balance'].to_f == balance
	  ledger_data.insert(index+1, ledger_data.delete_at(index+1+i))
	  found_out_of_order_transaction = true 
	end
      end
      if not found_out_of_order_transaction
        missing_transaction = {"type"=> "UNKNOWN",
			     "date" => "UKNOWN",
			     "amount"=> difference,
			     "balance"=> difference + ledger['balance'],
			     "requester"=> "UNKNOWN",
			     "source"=> {"description" => "UNKNOWN", "type"=>"UNKOWN"},
			     "destination"=> {"description" => "UNKNOWN", "type"=>"UNKOWN"}}
        ledger_data.insert(index+1, missing_transaction) 
      end
    end
  end
  ledger_data.each do |ledger|
    if ledger['source']['description'].nil?
      ledger['source']['description'] = ledger['source']['type']
    end
    if ledger['destination']['description'].nil?
      ledger['destination']['description'] = ledger['destination']['type']
    end
  end
end
