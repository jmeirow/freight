require_relative './allocation_periods.rb'
require_relative './repository.rb'
require_relative './date.rb'
require_relative './freight_account_entry.rb'
require 'pp'
require 'timecop'
require 'pstore'


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
    account_entries = repo.get_freight_account (member_id) 
    #
    #  FOR TESTING ONLY emp_stat_data = emp_stat_data.reject{|x| x.week_starting_date == Date.new(2012,5,13)}



    #
    # compute account additions from daily rate contributions
    #
    additions = FreightAccountEntry.get_additions_for_account(emp_stat_data, account_entries)
    repo.add additions
    #
    #




    #
    # compute reversals (correction) of daily rate contributions that have been deleted
    #
    deleted_weeks = FreightAccountEntry.get_deleted_weeks_for_account(emp_stat_data, account_entries)
    deletions = deleted_weeks.collect{|week| account_entries.find{|x| x.week_starting_date == week && x.is_contribution? }}
    repo.reverse (deletions)
    #
    #




    #
    # compute additions to account because previously created FB week(s) replaced by other coverage
    #
    create_adjustments_for_replaced_fb(member_id, account_entries)
    #
    #




    #
    # compute adjustments to account because of tiered rate changes or retro plan change
    #
    create_adjustments_when_amount_changes(member_id, account_entries) 
    #
    #


  end
end


def statements_have_never_run_before?
  last_run_date = nil
  store.transaction do 
    last_run_date = store['last_run_date']
  end
  last_run_date.nil? 
end


def time_to_create_statements?
  if statements_have_never_run_before? 
    return true if Date.today.day >= 20
  else 
    return true if Date.today.day >= 20 && consecutive_months?(Date.today,last_statement_run_date)
  end
  false
end

def get_people_who_need_coverage
  members_who_need_coverage
  repo = Eligibility::FreightAccumulation::Repository
  repo.freight_member_ids.each do |member_id|

    
  end
end 


def create_statements_for(people_who_need_coverage_and_have_money)
end


def record_statement_date
end


def get_people_with_sufficient_balances(people_who_need_coverage)

end



def create_statements
  people_who_need_coverage = get_people_who_need_coverage
  people_who_need_coverage_and_have_money = get_people_with_sufficient_balances(people_who_need_coverage)
  create_statements_for(people_who_need_coverage_and_have_money)
  record_statement_date
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



#
#  PROGRAM ENTRY POINT
#
#Timecop.travel(   Date.today  ) do 
Timecop.travel(   Date.new(2014,9,30)  ) do 
  include AllocationPeriods
  update_accounts
  create_statments if time_to_create_statements?
end
#
#






