require_relative './allocation_periods.rb'
require_relative './repository.rb'
require_relative './freight_account_entry.rb'
require 'pp'
require 'timecop'



def bootstrap    

  repo = Eligibility::FreightAccumulation::Repository
  ids = [42684]
  ids.each do |member_id|
  # repo.freight_member_ids.each do |member_id|


    emp_stat_data =   repo.half_pay_from_bbs_2012(member_id)

    emp_stat_data +=  repo.half_pay_weeks(member_id, half_pay_date_range)
    
    emp_stat_data = emp_stat_data.reject{|x| x.week_starting_date == Date.new(2012,5,13)}
  
    account_entries = repo.get_freight_account(member_id) 



    additions = FreightAccountEntry.get_additions_for_account(emp_stat_data, account_entries)

    repo.add additions




    deleted_weeks = FreightAccountEntry.get_deleted_weeks_for_account(emp_stat_data, account_entries)

    deletions = deleted_weeks.collect{|week| account_entries.find{|x| x.week_starting_date == week && x.is_contribution? }}
    

    repo.reverse   deletions

 

  end
end


Timecop.travel(Date.today) do 
  include AllocationPeriods
  bootstrap 
  # puts "#{half_pay_date_range.first.strftime('%m/%d/%Y')} - #{half_pay_date_range.last.strftime('%m/%d/%Y')}"
end



