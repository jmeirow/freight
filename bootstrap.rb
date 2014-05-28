require_relative './allocation_periods.rb'
require_relative './repository.rb'
require_relative './date.rb'
require_relative './freight_account_entry.rb'
require 'pp'
require 'timecop'
require 'pstore'

require 'pry'
require 'pry_debug'


FREIGHT_PSTORE = 'freight.pstore'
PSTORE_LAST_RUN = 'last_run_date'


def scratch
  # experimemtal code goes here....
end

def create_adjustments_when_amount_changes(member_id, account_entries)

  freight_repo = Eligibility::FreightAccumulation::Repository

  current_fb_weeks = FreightAccountEntry.get_account_current_coverage_entries(account_entries)

  current_fb_weeks.each do |fb_week|
    coverage_info = repo.get_rates_for_week_ending member_id, company_information_id ,fb_week.week_starting_date + 6
    if coverage_info.amount != fb_week.amount
      if coverage_info.BillingTier != fb_week.billing_tier 
         freight_repo.reverse_fb_week(fb_week, 'Billing tier changed')
      elsif coverage_info.plancode != fb_week_plan_code
        freight_repo.reverse_fb_week(fb_week, 'Plan code changed.')
      else
        freight_repo.reverse_fb_week(fb_week, 'Amount changed,  though plan code and billing tier are the same.')
      end
    end
  end
end


def create_adjustments_for_replaced_fb (member_id, account_entries)
  coverage_repo = Eligibility::Coverage::Repository
  freight_repo = Eligibility::FreightAccumulation::Repository
  current_fb_weeks = FreightAccountEntry.get_account_current_coverage_entries(account_entries)
  if current_fb_weeks.count > 0
    covered_weeks = coverage_repo.get_covered_weeks(member_id, current_fb_weeks.collect{|x| x.week_starting_date})
    covered_weeks.each {|entry| freight_repo.reverse_fb_week entry, 'Account credited for FB that was later replaced with other coverage.'  }
  end  
end


def update_accounts

  repo = Eligibility::FreightAccumulation::Repository
  repo.freight_member_ids.each do |member_id|

    #
    # get base data
    #
    emp_stat_data =   repo.half_pay_from_bbs_2012(member_id)
    emp_stat_data +=  repo.half_pay_weeks(member_id, half_pay_date_range)
    account_entries = repo.get_freight_account(member_id) 
    #
    #emp_stat_data = emp_stat_data.reject{|x| x.week_starting_date == Date.new(2012,5,13)}

    #
    # compute account additions from daily rate contributions
    #
    additions = FreightAccountEntry.get_additions_for_account(emp_stat_data, account_entries)
    extra = additions.select{|x|  x.member_id ==  72075 }.collect{|x| x }
    if member_id == 72075
      additions += extra
    end

    repo.add additions, FreightAccountEntry.contribution
    #
    #

    account_entries = repo.get_freight_account (member_id) 


    #
    # compute reversals (correction) of daily rate contributions that have been deleted
    #
    deleted_weeks = FreightAccountEntry.get_deleted_weeks_for_account(emp_stat_data, account_entries)
    deletions = deleted_weeks.collect{|week| account_entries.find{|x| x.week_starting_date == week && x.is_contribution? }}
    repo.reverse (deletions)
    #
    #

    account_entries = repo.get_freight_account (member_id) 
    # pp account_entries

    #
    # compute additions to account because previously created FB week(s) replaced by other coverage
    #
    # create_adjustments_for_replaced_fb(member_id, account_entries)
    #
    #

    account_entries = repo.get_freight_account (member_id) 


    #
    # compute adjustments to account because of tiered rate changes or retro plan change
    #
    # create_adjustments_when_amount_changes(member_id, account_entries) 
    #
    #

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

  return true

  if statements_have_never_run_before? 
    return true if Date.today.day >= 20
  else 
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
    next unless member_id == 72075

    Date.today.mctwf_next_months_weeks.each do |week_starting_date|
      if elig_repo.is_covered?(member_id, week_starting_date) == false
        people_with_gaps << {:member_id => member_id, :week_starting_date => week_starting_date}
        break
      end
    end
  end
  people_with_gaps
end 

def create_statements_for(people_who_need_coverage_and_have_money)
  repo = Eligibility::FreightAccumulation::Repository
  benefit_repo = Eligibility::FreightBenefit::Repository
  people_who_need_coverage_and_have_money.each do |record|
    new_record = record.merge(:user_date => Time.now,
                 :is_reversal => 'N',
                 :plan_code => 'ABC',
                 :note => '')

    new_record[:amount] = ( new_record[:amount] * Money.new(-1))
    repo.add [FreightAccountEntry.new(new_record)], FreightAccountEntry.coverage
    benefit_repo.add new_record[:member_id], new_record[:week_starting_date] + 6

  end
end

def record_statement_date
  store = PStore.new(FREIGHT_PSTORE) 
  store.transaction do 
    store[PSTORE_LAST_RUN] = Time.now
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
  account_entries = repo.get_freight_account (member_id) 
  account_entries.sort{|x,y| x.user_date <=> y.user_date}
                                .select{|x| (x.is_reversal? == false) && (x.is_coverage?)}.last 
end


def has_coverage_entry_in_account?(member_id)
  
  last_coverage_entry_in_account(member_id).nil? == false 
end


def people_with_sufficient_balances

  results = []

  rate_repo = Billing::Rates::RatesForWeeks
  repo = Eligibility::FreightAccumulation::Repository
  repo.freight_member_ids.each do |member_id| 

    #week_starting_date = person[:week_starting_date]
    week_ending_date = Date.today.mctwf_next_months_weeks.first + 6
    account_entries = repo.get_freight_account(member_id)

    company_information_id = FreightAccountEntry.get_employer_id(account_entries)

    rate_info = rate_repo.get_rates_for_week_ending(member_id, company_information_id ,week_ending_date)
    balance = FreightAccountEntry.balance(repo.get_freight_account (member_id))
 
    if (  balance  >= rate_info[:amount] )
          results << person.merge(
                        :amount => rate_info[:amount], 
                        :company_information_id => company_information_id )
    end
  end
  results 
end

def request_elig_be_run_for_all_fb_members
end

def create_statements


  #
  # identify those freight people  
  #
  #have_gap_next_month = people_with_coverage_gap_next_month
  #
  #

  #
  # of those people who have a coverage gap next month, get those who have enough balance to buy an FB for that week 
  #
  people_who_need_coverage_and_have_money =  people_with_sufficient_balances
  #
  #


  #
  # create statements for those people for whom coverage was created. 
  #
  create_statements_for(people_who_need_coverage_and_have_money)
  #
  # 
  


  #
  # Since every one's FB data was wiped out at the start of the nightly batch we need to 
  # insure their eligibility is recomputed.
  #
  request_elig_be_run_for_all_fb_members
  #
  #



  #
  # record this run date in pstore 
  #
  record_statement_date
  #
  #
end

#
#  PROGRAM ENTRY POINT
#
include AllocationPeriods

if ARGV[0].chomp == 'run'
  puts "Running..."
  Timecop.travel(   Time.now  ) do 
    update_accounts if (1..5).cover?Date.today.wday
    create_statements if time_to_create_statements?
  end
end


if ARGV[0].chomp == 'summary'
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


if ARGV[0].chomp == 'balances'
  puts "Retrieving Balances...."
    
    Reporting::TableCounts.balances.sort{|x,y| x[:amount].amount <=> y[:amount].amount}.each do |record|
      puts "#{record[:member_id]}   #{record[:amount]}"
    end
end


#
#






