require_relative './allocation_periods.rb'
require_relative './repository.rb'
require_relative './date.rb'
require_relative './freight_account_entry.rb'
require 'pp'
require 'timecop'
require 'pstore'




FREIGHT_PSTORE = 'freight.pstore'
PSTORE_LAST_RUN = 'last_run_date'


class Object
  def safe_value 
    if self.nil?
      ""
    else 
      self
    end
  end
end


def scratch
  # experimemtal code goes here....
end


def create_adjustments_when_amount_changes(member_id, account_entries)

  current_fb_weeks = FreightAccountEntry.get_account_current_coverage_entries(account_entries)

  current_fb_weeks.each do |fb_week|
    coverage_info = repo.get_rates_for_week_ending member_id, company_information_id ,fb_week.week_starting_date + 6
    if coverage_info.amount != fb_week.amount
      if coverage_info.BillingTier != fb_week.billing_tier 
         Eligibility::FreightAccumulation::Repository.reverse_fb_week(fb_week, 'Billing tier changed')
      elsif coverage_info.plancode != fb_week_plan_code
        Eligibility::FreightAccumulation::Repository.reverse_fb_week(fb_week, 'Plan code changed.')
      else
        Eligibility::FreightAccumulation::Repository.reverse_fb_week(fb_week, 'Amount changed,  though plan code and billing tier are the same.')
      end
    end
  end
end


def create_adjustments_for_replaced_fb (member_id, account_entries)
  
  current_fb_weeks = FreightAccountEntry.get_account_current_coverage_entries(account_entries)
 

  if current_fb_weeks.count > 0
    covered_weeks = Eligibility::Coverage::Repository.get_covered_weeks(member_id)
    reversed_weeks = current_fb_weeks.select{|x| covered_weeks.include?(x.week_starting_date)}
    reversed_weeks.each do |entry| 
      Eligibility::FreightAccumulation::Repository.reverse_fb_week(entry, 'Account credited for FB that was later replaced with other coverage.')
    end
  end  
end


def update_accounts
  if (1..5).cover?Date.today.wday
    puts "Updating accounts..."
    Eligibility::FreightAccumulation::Repository.freight_member_ids.each do |member_id|
    

      #
      # get base data
      #
      emp_stat_data =nil 

      if first_allocation_period.cover?Date.today 
        emp_stat_data =   Eligibility::FreightAccumulation::Repository.half_pay_from_bbs_2012(member_id)
        emp_stat_data +=  Eligibility::FreightAccumulation::Repository.half_pay_weeks(member_id, half_pay_date_range)
      else
        emp_stat_data = Eligibility::FreightAccumulation::Repository.half_pay_weeks(member_id, current_allocation_period)
      end


      account_entries = Eligibility::FreightAccumulation::Repository.get_freight_account(member_id) 


      #
      # compute account additions from daily rate contributions
      #
      additions = FreightAccountEntry.get_additions_for_account(emp_stat_data, account_entries)


      #
      # add entries to account...
      #
      Eligibility::FreightAccumulation::Repository.add additions, FreightAccountEntry.contribution, 'N'
   

      #
      # re-fetch the updated account data...
      #
      account_entries = Eligibility::FreightAccumulation::Repository.get_freight_account (member_id) 


      #
      # compute reversals (correction) of daily rate contributions that have been deleted
      #
      deleted_weeks = FreightAccountEntry.get_deleted_weeks_for_account(emp_stat_data, account_entries)
      deletions = deleted_weeks.collect{|week| account_entries.find{|x| x.week_starting_date == week && x.is_contribution? }}
      Eligibility::FreightAccumulation::Repository.reverse (deletions)
   


      #
      # re-fetch the updated account data...
      #
      account_entries = Eligibility::FreightAccumulation::Repository.get_freight_account (member_id) 







      #
      # compute additions to account because previously created FB week(s) replaced by other coverage
      #
      create_adjustments_for_replaced_fb(member_id, account_entries)
      

      #
      # re-fetch the updated account data...
      #
      account_entries = Eligibility::FreightAccumulation::Repository.get_freight_account (member_id) 



      #
      # compute adjustments to account because of tiered rate changes or retro plan change
      #
      # create_adjustments_when_amount_changes(member_id, account_entries) 
      #
      #
    end
  else
    puts "Today is a weekend. Not updating accounts."
  end

end


def statements_have_never_run_before?
  last_run_date = nil
  store = PStore.new(FREIGHT_PSTORE)
  store.transaction do 
    last_run_date = store[PSTORE_LAST_RUN]
  end
  last_run_date.nil? 
end


def last_statement_run_date
  store = PStore.new(FREIGHT_PSTORE)
  last_run_date = nil
  store.transaction do    
    last_run_date = store[PSTORE_LAST_RUN]
  end
  last_run_date.to_date
end


def time_to_create_statements?
  

  if statements_have_never_run_before? 
    return true if Date.today.day >= 20
  else
    return true if Date.today.day == 20
    return true if  Date.today.day >= 20 && 
        consecutive_months?(Date.today,last_statement_run_date) &&
        current_allocation_period.cover?(Date.today) && current_allocation_period.cover?(Date.today+30)
  end
  false
end


def people_with_coverage_gap_next_month
  people_with_gaps = []
  repo = Eligibility::FreightAccumulation::Repository
  elig_repo = Eligibility::Coverage::Repository 
  repo.freight_member_ids.each do |member_id|
    Date.today.mctwf_next_months_weeks.each do |week_starting_date|
      if elig_repo.is_covered?(member_id, week_starting_date) == false
        people_with_gaps << {:member_id => member_id, :week_starting_date => week_starting_date}
        break
      end
    end
  end
  people_with_gaps
end 



def create_statements_for(people_with_enough_money,statement_date)

  people_with_enough_money.each do |record|
    new_record = record.merge(:user_date => Time.now,
                 :is_reversal => 'N',
                 :note => '')


    #
    # Insert to the statement
    #
    FreightStatement.insert_freight_stmt_record new_record, statement_date
    

    #
    # insert to the account
    #
    new_record[:amount] = Money.new(new_record[:amount].amount * -1)
    Eligibility::FreightAccumulation::Repository.add_coverage_record FreightAccountEntry.new(new_record), FreightAccountEntry.coverage, 'N'
  end
end


def create_freight_benefit_records

  Eligibility::FreightAccumulation::Repository.freight_member_ids.each do |member_id|
    account_entries =  Eligibility::FreightAccumulation::Repository.get_all_freight_account member_id
    coverage_entries = FreightAccountEntry.get_account_current_coverage_entries(account_entries)

    if coverage_entries.count > 0
      coverage_entries.each do |entry|
        Eligibility::FreightBenefit::Repository.save entry.member_id, coverage_entries.collect{|x| x.week_starting_date + 6 }
      end
    end
  end
end

 
def record_statement_date statement_datetime
  store = PStore.new(FREIGHT_PSTORE) 
  store.transaction do 
    store[PSTORE_LAST_RUN] = statement_datetime
  end
end


def lesser_of(d1, d2)
  if d1 < d2 
    d1
  else
    d2
  end
end


def greater_of(d1, d2)
  if d1 > d2 
    d1
  else
    d2
  end
end


def consecutive_months?(d1, d2)
  if d1.year == d2.year
    return true if (d1.month - d2.month).abs == 1
  else
    first = lesser_of(d1,d2)
    second = greater_of(d1,d2)
    return true  if (((first.year + 1) == second.year) && (first.month == 12) && (second.month == 1)   )
    false 
  end
end


def last_coverage_entry_in_account(member_id)
  repo = Eligibility::FreightAccumulation::Repository
  account_entries = Eligibility::FreightAccumulation::Repository.get_freight_account (member_id) 
  account_entries.sort{|x,y| x.user_date <=> y.user_date}
                                .select{|x| (x.is_reversal? == false) && (x.is_coverage?)}.last 
end


def has_coverage_entry_in_account?(member_id)
  
  last_coverage_entry_in_account(member_id).nil? == false 
end


def add_to_collection_if_sufficient_balance member_id, results, gaps 


  gap = gaps.find{|x| x[:member_id] == member_id}


  if gap 
    week_ending_date = gap[:week_starting_date] + 6
  else
    week_ending_date = Date.today.mctwf_next_months_weeks.first + 6
  end

  account_entries = Eligibility::FreightAccumulation::Repository.get_freight_account(member_id)
  return if account_entries.count == 0

  balance = FreightAccountEntry.balance(account_entries)
  company_information_id = FreightAccountEntry.get_employer_id(account_entries)
  rate_info = Billing::Rates::RatesForWeeks.get_rates_for_week_ending(member_id, company_information_id ,week_ending_date)

  if (balance  >= rate_info[:amount] )

    record =  {:member_id => member_id, :amount => rate_info[:amount], :plan_code => rate_info[:plan_code], :billing_tier => rate_info[:billing_tier], :company_information_id => company_information_id, :is_coverage_applied => 'N',
                :week_applied_start => nil, :week_applied_end => nil, :week_starting_date => week_ending_date -6 }


    if gap
      record = record.merge({:week_applied_start => gap[:week_starting_date], :week_applied_end => week_ending_date, :is_coverage_applied => 'Y' }) 
    end

    results << record 
  end

end


def people_with_sufficient_balances

  gaps = people_with_coverage_gap_next_month

  results = []
  Eligibility::FreightAccumulation::Repository.freight_member_ids.each do |member_id| 
    add_to_collection_if_sufficient_balance member_id, results, gaps
  end
  results 
end


def request_elig_be_run_for_all_fb_members
  Eligibility::FreightAccumulation::Repository.freight_member_ids.each do |member_id| 
    Eligibility::FreightBenefit::Repository.insert_into_changed_member_id(member_id)
  end
end


def create_statements

  if time_to_create_statements? == false
    puts "Statements not created."
  else 

    puts "Creating statements..."

    #
    # set the statement date to today (do this in case we run past midnight.  Don't used "Date.today" for long running batch processes.)
    #
    statement_datetime  = Time.now
    statement_date      = Date.today 


    #
    # create statements for those people for whom coverage was created. 
    #
    create_statements_for(people_with_sufficient_balances, statement_date )
    


    #
    # (Re)Create freight benefit records. 
    #
    create_freight_benefit_records



    #
    # Since every one's FB data was wiped out at the start of the nightly batch we need to 
    # insure their eligibility is recomputed.
    #
    request_elig_be_run_for_all_fb_members



    #
    # record this run date in pstore 
    #
    record_statement_date statement_datetime

  end
end





#
#
#
# program main stubs...
#
#
#
def run
  puts "Called with time of #{Time.now.strftime("%m/%d/%Y %H:%M:%S %P")}"
  update_accounts 
  create_statements 
end

def summary 
  puts "Retrieving Info...."
  store = PStore.new(FREIGHT_PSTORE)
  store.transaction do    
    x = store[PSTORE_LAST_RUN]
    puts "\n\n\n"
    puts "---------------------------------------------------------------"
    puts "This process last ran at: #{x.strftime('%m/%d/%Y %H:%M:%S %P')}"
    puts "\n\n"
    puts "Table Row Counts:\n"
    puts "---------------------------------------------------------------"

    puts "FreightAccount:      #{Reporting::TableCounts.freight_account_rows}"
    puts "FreightBenefit:      #{Reporting::TableCounts.freight_benefit_rows}"
    puts "FreightStatement:    #{Reporting::TableCounts.freight_statement_rows}"

  end
end


def test arg_time 
  time = Time.strptime(arg_time, "%m/%d/%Y %H:%M:%S %P")

  if ENV['ENVIRONMENT'].nil? || (ENV['ENVIRONMENT'] != 'development' && ENV['ENVIRONMENT'] != 'test')
    puts "Unable to verify this machine is a 'dev' or 'test' machine. Quitting..."
  else   
    Timecop.travel(  time  ) do 
      run
    end
  end
end


def test_x_days days

  (1..days).each do |idx|

    time = (Date.today + idx).to_time

    puts "\n\nRunning for date:  #{time.to_date.strftime('%A   %m/%d/%Y')}"
    if ENV['ENVIRONMENT'].nil? || (ENV['ENVIRONMENT'] != 'development' && ENV['ENVIRONMENT'] != 'test')
      puts "Unable to verify this machine is a 'dev' or 'test' machine. Quitting..."
    else   
      Timecop.travel(  time  ) do
        Eligibility::FreightBenefit::Repository.delete_all 
        run
      end
    end
  end
end


def test_statements months

  date = Date.new(2014,5,15)
  puts "TODAY is #{Date.today}"
  (0..months).each do |idx|

    time  = date.next_statement_date.to_time
    
    if ENV['ENVIRONMENT'].nil? || (ENV['ENVIRONMENT'] != 'development' && ENV['ENVIRONMENT'] != 'test')
      puts "Unable to verify this machine is a 'dev' or 'test' machine. Quitting..."
    else   
      Timecop.travel(  time  ) do
        Eligibility::FreightBenefit::Repository.delete_all
        puts "\n\nRunning for date:  #{time.to_date.strftime('%A   %m/%d/%Y')}" 
        run
      end
    end
  
    date = time.to_date 

  end
end

def balances
  puts "Retrieving Balances...."
    
    Reporting::TableCounts.balances.sort{|x,y| x[:amount].amount <=> y[:amount].amount}.each do |record|
      puts "#{record[:member_id]}   #{record[:amount]}"
    end
end


def help

  puts "\n\nInvoke program like this:   $ bundle exec ruby bootstrap.rb <command> <options>\n\n"

  puts "COMMAND <OPTS>   DESCRIPTION"
  puts "--------------   ---------------------------------------------------------------------------------------------------------"
  puts "run              Runs program in production mode.\n"
  puts "test <date>      Runs program in test/development mode. 'date' is passed as m/d/yyyy and sets the system to that date.\n"
  puts "summary          Prints a summary of row counts in FreightAccount and FreightBenefit tables.\n"
  puts "balances         Displays all member_ids and their account balances, sorting lowest to highest.\n"
  puts "show <member_id> Lists account entries for the member specified by member_id.\n"
  puts "\n\n\n"
end


def show member_id 

  entries = Eligibility::FreightAccumulation::Repository.get_freight_account(member_id)

  balance =  FreightAccountEntry.balance(entries)

  puts "\n\n\n\n****** Account Balance: #{balance}  ********\n\n"



  puts "MBR ID    EMP ID   WS DATE                 AMT          TIER     PLAN CD   REVERSAL?              TYPE                  USER DT "
  puts "------    ------   -------        ------------   -----------     -------   ---------      ------------  -----------------------\n"

  entries.each do |entry| 
    memberid = "%5s"  % entry.member_id
    company_information_id = "%5s"  % entry.company_information_id
    week_starting_date = "%10s" % entry.week_starting_date.strftime("%m/%d/%Y")
    amount = "%15s" % entry.amount.to_s.safe_value 
    plan_code = "%10s" %  entry.plan_code.safe_value 
    is_reversal =  entry.is_reversal.safe_value
    entry_type = "%15s" %   entry.entry_type.safe_value
    billing_tier = "%10s" %  entry.billing_tier.safe_value.gsub!(/ /,'.')  
    user_date = "%15s" % entry.user_date.strftime("%m/%d/%Y %H:%M:%S %P")

    plan_code.gsub!(/ /,'.')  
    is_reversal.gsub!(/ /,'.') 
    billing_tier.gsub!(/ /,'.')  

    puts "#{memberid}    #{company_information_id}     #{week_starting_date.strip}  #{amount}    #{billing_tier}  #{plan_code}      #{is_reversal}        #{entry_type}   #{user_date}"
  end
end

def reset 
  Util.reset
end


#
#
#
# Entry point
#
#
#

include AllocationPeriods

cmd_found = false 

cmd = ARGV[0].chomp
opt = ARGV[1].chomp if ARGV[1]

if cmd == 'run'
  cmd_found = true
  run 
  elsif cmd == 'test'
    cmd_found = true
    test opt
  elsif cmd == 'test_statements'
    cmd_found = true
    test_statements opt.to_i
  elsif cmd == 'test_x_days'
    cmd_found = true
    test_x_days opt.to_i
  elsif cmd == 'summary'
    cmd_found = true
    summary 
  elsif cmd == 'balances'
    cmd_found = true
    balances
  elsif cmd == 'show'
    cmd_found = true  
    show opt
  elsif cmd == 'help'
    cmd_found = true
    help
  elsif cmd == 'reset'
    cmd_found = true
    reset
end
 
puts "\nCommand not recognized.\n" unless cmd_found 
