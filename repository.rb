require 'sequel'
require 'tiny_tds'  
require 'date'
require 'pp'
require './money'

module Employment
  module EmploymentHistory
    class Repository
      
      def self.get_by_member_and_company member_id, company_id 

        db = Connection.db_teamsters
        sql = "SELECT * FROM ParticipantEmploymentHistory where MemberId = ? and CompanyInformationId = ? ORDER BY FromDate"

        records = Array.new

        db.fetch(sql,member_id, company_id) do |row|
          hash = Hash.new
          hash[:member_id] = row[:memberid]
          hash[:company_information_id] = row[:companyinformationid]
          hash[:employment_status] = row[:employmentstatus]
          hash[:from_date] = row[:fromdate].to_date
          hash[:to_date] = row[:todate].to_date
          records << hash
        end
        records
      end  
    
      def self.get_uncovered_weeks_and_rate member_id 
      end
    end  #class
  end  #module..
end  # module..

module  Billing
  module Calendar 

    # class BillingPeriod
    #   def self.distinct_billing_periods_for_weekendings weekendings
    #     db = Connection.db_teamsters
    #     sql = "
    #       select distinct Period from BillingPeriodWeekWEnds 
    #       where WeekEnding  between ? and ? 
    #     "
    #   results = []
    #   db.fetch(sql,week_endings.first, weekendings.last ).each do |row| 
    #     results << row[:period]
    #   end
    #   results
    #   end
    # end
  end 



  module Rates
    class TieredRates
      def self.get_billing_tier_for company_id, member_id 

      end 
    end


    class RatesForWeeks
      def self.get_rates_for_periods member_id, company_information_id ,periods
        raise "exactly three periods required" unless periods.length == 3
        period1 = "'#{periods[0]}'"; period2 = "'#{periods[1]}'"; period3 = "'#{periods[2]}'"
        db = Connection.db_teamsters

        sql = "select TierRate, CompanyInformationId, memberId, WeekEnding, Z.PlanHeaderId, LotTpdAndDeathAmount,
              Rate = 
              case
                when NumberOfBillingTiers = 0 Then MedicalRateComposite
              else
                case 
                  when TierRate = 'Single' then MedicalRateSingle
                  when TierRate = 'Family' then MedicalRateFamily
                  when TierRate = 'Middle' then MedicalRateMiddle
                  when TierRate = 'MemberandChildren' then MedicalMemberPlusChildrenRate
                end
              end
    
              
             from (     
            SELECT DISTINCT 
            VC.IndustryCode, C.CompanyInformationId, M.MemberID,  VC.NumberOfBillingTiers ,M.EnrollmentCardStatus, M.MemberSSN, M.MemberFirstName,   
               M.MemberLastName, M.MemberMiddleName,   C.MemberHireDate, VC.Period,   
               VC.Weekending, VC.WeekNo, VC.IsTieredPricingAllowed,IsNull(SP.SPOUSE, 'N') AS Spouse, IsNull(KD.KIDS, 'N') AS Kids,   
               TierRate = CASE  
                  WHEN M.EnrollmentCardStatus <> 'Y'  
                  THEN 'Family'  
                  WHEN (SP.Spouse = 'Y' AND KD.Kids = 'Y')  
                  THEN 'Family'  
                  WHEN ((SP.Spouse = 'N' OR SP.Spouse IS NULL) AND KD.Kids = 'Y' AND VC.NumberOfBillingTiers = 4)  
                  THEN 'MemberandChildren'  
                  WHEN ((SP.Spouse = 'N' OR SP.Spouse IS NULL) AND KD.Kids = 'Y' AND VC.NumberOfBillingTiers = 3)  
                  THEN 'Middle'  
                  WHEN (SP.Spouse = 'Y' AND (KD.Kids = 'N' OR KD.Kids IS NULL))  
                  THEN 'Middle'  
                  WHEN ((SP.Spouse = 'N' AND KD.Kids = 'N') OR (SP.Spouse IS NULL AND KD.Kids IS NULL))  
                  THEN 'Single'  
                  END,  
             
               VC.CollAgreementEffectiveDate AS CBAEffectiveDate, VC.CollAgreementTerminationDate AS CBATerminationdate, VC.ContributionPlanID,   
               VC.PlanCode, VC.MedicalRateSingle, VC.MedicalRateFamily, VC.MedicalRateComposite, VC.MedicalRateMiddle, VC.PlanHeaderID, 
               VC.MedicalRateMBRBSingle, VC.MedicalRateMBRBFamily, VC.MedicalRateMBRBComposite, VC.MedicalRateMBRBMiddle, VC.DailyRates,  
               VC.ContPlanEffectiveDate AS ContributionPlanEffectiveDate, VC.ContPlanTerminationDate AS ContributionPlanTerminationDate, VC.BillingUnit,  
                VC.MedicalMemberPlusChildrenRate 
               
            FROM MemberDemographic M  
            INNER JOIN CompanyMember C  
            ON M.MemberID = C.MemberID  
            INNER JOIN vw_CurrentCBAandRate VC  
            ON C.CompanyInformationID = VC.CompanyInformationID  
            LEFT OUTER JOIN  
             (  
              SELECT DP.MemberID, /*DP.DependentID,*/BW.Period, BW.Weekending,Spouse = 'Y', COUNT(DP.DependentID) AS SpouseCount--,BillingEffectiveDate, BillingTerminationDate  
              FROM DependentRecords DR   
               INNER JOIN Dependents DP   
                ON DR.DependentID = DP.DependentID  
               INNER JOIN  
                (  
                 SELECT DependentID,   
                 BilingStartDate = CASE (DATEPART(dw, BillingEffectiveDate) + @@DATEFIRST) % 7  
                      WHEN 1 THEN DATEADD(DAY,6,BillingEffectiveDate)--'Sunday'  
                      WHEN 2 THEN DATEADD(DAY,5,BillingEffectiveDate)--'Monday'  
                      WHEN 3 THEN DATEADD(DAY,4,BillingEffectiveDate)--'Tuesday'  
                      WHEN 4 THEN DATEADD(DAY,3,BillingEffectiveDate)--'Wednesday'  
                      WHEN 5 THEN DATEADD(DAY,2,BillingEffectiveDate)--'Thursday'  
                      WHEN 6 THEN DATEADD(DAY,1,BillingEffectiveDate)--'Friday'  
                      WHEN 0 THEN DATEADD(DAY,0,BillingEffectiveDate)--'Saturday'  
                       END,             
                 BilingEndDate = CASE (DATEPART(dw, BillingTerminationDate) + @@DATEFIRST) % 7  
                      WHEN 1 THEN DATEADD(DAY,6,BillingTerminationDate)--'Sunday'  
                      WHEN 2 THEN DATEADD(DAY,5,BillingTerminationDate)--'Monday'  
                      WHEN 3 THEN DATEADD(DAY,4,BillingTerminationDate)--'Tuesday'  
                      WHEN 4 THEN DATEADD(DAY,3,BillingTerminationDate)--'Wednesday'  
                      WHEN 5 THEN DATEADD(DAY,2,BillingTerminationDate)--'Thursday'  
                      WHEN 6 THEN DATEADD(DAY,1,BillingTerminationDate)--'Friday'  
                      WHEN 0 THEN DATEADD(DAY,0,BillingTerminationDate)--'Saturday'  
                       END   
                 FROM DependentRecords       
                ) DB  
                ON DB.DependentID = DP.DependentID  
               INNER JOIN  BillingPeriodWeekEnds BW     
                ON BW.Weekending BETWEEN DB.BilingStartDate AND DB.BilingEndDate     
              WHERE DR.DependentRelationCode IN  ('H','W')  
              AND BW.Period in  (#{period1}, #{period2}, #{period3}) 
              GROUP BY DP.MemberID, BW.Period, BW.Weekending   
             ) SP  
            ON M.MemberID = SP.MemberID  
            AND VC.Weekending = SP.WeekEnding  
            LEFT OUTER JOIN  
             (  
              SELECT DP.MemberID, /*DP.DependentID,*/BW.Period, BW.Weekending,Kids = 'Y', COUNT(DP.DependentID) AS KidsCount--,BillingEffectiveDate, BillingTerminationDate  
              FROM DependentRecords DR   
               INNER JOIN Dependents DP   
                ON DR.DependentID = DP.DependentID  
              INNER JOIN  
                (  
                 SELECT DependentID,   
                 BilingStartDate = CASE (DATEPART(dw, BillingEffectiveDate) + @@DATEFIRST) % 7  
                      WHEN 1 THEN DATEADD(DAY,6,BillingEffectiveDate)--'Sunday'  
                      WHEN 2 THEN DATEADD(DAY,5,BillingEffectiveDate)--'Monday'  
                      WHEN 3 THEN DATEADD(DAY,4,BillingEffectiveDate)--'Tuesday'  
                      WHEN 4 THEN DATEADD(DAY,3,BillingEffectiveDate)--'Wednesday'  
                      WHEN 5 THEN DATEADD(DAY,2,BillingEffectiveDate)--'Thursday'  
                      WHEN 6 THEN DATEADD(DAY,1,BillingEffectiveDate)--'Friday'  
                      WHEN 0 THEN DATEADD(DAY,0,BillingEffectiveDate)--'Saturday'  
                       END,             
                 BilingEndDate = CASE (DATEPART(dw, BillingTerminationDate) + @@DATEFIRST) % 7  
                      WHEN 1 THEN DATEADD(DAY,6,BillingTerminationDate)--'Sunday'  
                      WHEN 2 THEN DATEADD(DAY,5,BillingTerminationDate)--'Monday'  
                      WHEN 3 THEN DATEADD(DAY,4,BillingTerminationDate)--'Tuesday'  
                      WHEN 4 THEN DATEADD(DAY,3,BillingTerminationDate)--'Wednesday'  
                      WHEN 5 THEN DATEADD(DAY,2,BillingTerminationDate)--'Thursday'  
                      WHEN 6 THEN DATEADD(DAY,1,BillingTerminationDate)--'Friday'  
                      WHEN 0 THEN DATEADD(DAY,0,BillingTerminationDate)--'Saturday'  
                       END   
                 FROM DependentRecords       
                ) DB  
                ON DB.DependentID = DP.DependentID  
               INNER JOIN  BillingPeriodWeekEnds BW     
                ON BW.Weekending BETWEEN DB.BilingStartDate AND DB.BilingEndDate     
              WHERE DR.DependentRelationCode IN  ('SA','S','SP','SH','MG','D','FG','DP','DH','PD','O' ,'SS','PS','DA','SD')  
              AND BW.Period in (#{period1}, #{period2}, #{period3})  
              GROUP BY DP.MemberID, BW.Period, BW.Weekending  
             ) KD  
            ON M.MemberID = KD.MemberID  
            AND VC.Weekending = KD.WeekEnding  
              
            WHERE (M.MemberID = #{member_id} OR M.MemberID = 0)
            AND VC.Period in (#{period1}, #{period2}, #{period3})  
            AND C.CompanyInformationID = #{company_information_id}  
            ) Z



          INNER JOIN (
          Select PlanHeaderId, Sum(RateAmount) LotTpdAndDeathAmount 
          From MCTWFPortal.dbo.RCBenefitTypeRate rate
          INNER JOIN BenefitType  bt on bt.BenefitTypeId = rate.BenefitTypeId 
          INNER JOIN PlanDetail pd on pd.BenefitTypeID = bt.BenefitTypeId
          Where bt.BenefitId In (3, 7 , 8)
          And  #{period1} between RateStartDate and RateEndDate
          group by PlanHeaderId
          ) Y on Z.PlanHeaderID = Y.PlanHeaderID


        "
        File.open("test.sql", "a") do |f|
          f.puts sql
        end

        results = []
        db.fetch(sql).each do |row| 
          record = {}
          record[:member_id] = row[:memberid]
          record[:company_information_id] = row[:companyinformationid]
          record[:week_ending] = row[:weekending].to_date
          record[:amount] = Money.new(row[:rate]) - Money.new(row[:lottpdanddeathamount])
          results << record
        end
        results
      end
    end
  end
  module Periods
    class Repository
      def self.get_max_billing_period_for_member id 
        db = Connection.db_teamsters
        sql = " 
        select CONVERT(DATE,IsNull(max(BillingDate),'1/1/1900')) as max_billing_date
        from BillData bd
        INNER JOIN BillItem bi on bd.BillDataNumber = bi.BillDataNumber
        WHERE bi.MemberId = ?  and (Week1 = 'AC' OR Week2 = 'AC' OR Week3 = 'AC' OR Week4 = 'AC' OR ISNULL(Week5,'') = 'AC')"
        File.open("dump.sql","a") do |f|
          f.puts sql 
        end

        result = Date.today
        db.fetch(sql,id).each do |row| 
          result = row[:max_billing_date]
        end
        result
      end
      def self.get_current_plan company_information_id, week_ending 

        db = Connection.db_teamsters
        sql = "Select PlanCode as plan_code
              from VW_CurrentCBAandRate
              where CompanyInformationID = ?
              and Weekending = ?"
        result ''
        db.fetch(sql,company_information_id, week_ending).each do |row| 
          result = row[:plan_code]
        end
        result
      end 
    end
  end
end


module Eligibility
  module FreightCoverage
    class Repository
      def self.insert_changed_member_id member_id  
        db = Connection.db_teamsters
        sql = "INSERT INTO ChangedMemberId ( MemberID, TableName, ActionCd  ) VALUES (?, 'BasicEligibilityMembers', 'U'  ) "
        db[sql, member_id ].insert 
      end
    end
  end

  module FreightAccumulation
    class Repository
      def self.save journal  
        db = Connection.db_teamsters
        db["DELETE FROM FreightJournal WHERE MemberId = ?", journal.records.first[:member_id]].delete
        sql = "INSERT INTO FreightJournal (MemberId, CompanyInformationId, WeekStarting, Amount, IsAdjustment, EntryType, UserId, UserDate )
        VALUES (?, ?, ?, ?, ?, ?, ?, ? ) "
        journal.records.each do |entry|

          db[sql, entry[:member_id]  , entry[:company_information_id]  , entry[:week_starting]  , entry[:amount].amount  , entry[:is_adjustment]  , entry[:entry_type] , entry[:user_id], Time.now ].insert 
        end
      end


      def self.half_pay_weeks_for_accumulation member_id 
        db = Connection.db_teamsters
        sql = "SELECT DateAdd(DAY,-6,WeekEnding) WeekStarting, MemberID, CompanyInformationID , EmploymentStatus , WeekNo as WeekNbr
          FROM BillingPeriodWeekEnds A
          INNER JOIN ParticipantEmploymentHistory B on A.WeekEnding between b.FromDate and b.ToDate
          WHERE WeekEnding >= ? AND EmploymentStatus = 'CH' and MemberID = ? and B.CompanyInformationID in 
          (
              select distinct bd.CompanyInformationID
              from BillData bd
              INNER JOIN BillItem bi on bd.BillDataNumber = bi.BillDataNumber
              WHERE bi.MemberId = ?

            )
          ORDER by 2, 1"

        File.open("accum.sql", "a") do |f|
          f.puts sql 
        end
        
        records = []
        db.fetch(sql, FREIGHT_ACCUM_START_DATE, member_id, member_id  ).each do |row|
          hash = Hash.new
          hash[:member_id] = row[:memberid]
          hash[:week_starting] = row[:weekstarting].to_date
          hash[:company_information_id] = row[:companyinformationid]
          hash[:employment_status] = row[:employmentstatus]
          hash[:week_nbr] = row[:weeknbr]
          hash[:user_date] =  row[:weekstarting].to_date
          hash[:amount] = Money.new(34.00)
          records << hash        
        end
        records
      end
 

    
      def self.get_freight_journal member_id 
        db = Connection.db_teamsters
        sql = "SELECT   MemberId , CompanyInformationId , WeekStarting ,Amount , IsAdjustment,  EntryType, UserDate   
        from FreightJournal where MemberID = ?"
        records = []
        db.fetch(sql, member_id).each do |row|
          hash = Hash.new
          hash[:member_id] = row[:memberid]
          hash[:week_starting] = row[:weekstarting].to_date
          hash[:company_information_id] = row[:companyinformationid]
          hash[:is_adjustment] = row[:isadjustment]
          hash[:user_date] = row[:userdate].to_date
          hash[:entry_type] =  row[:entrytype]
          hash[:amount] = Money.new(34.00)
          records << hash        
        end
        records
      end


      def self.freight_guys_since_apr_2014
        db = Connection.db_teamsters
        sql = "select distinct MemberId from ParticipantEmploymentHistory where EmploymentStatus = 'CH' and ToDate >= ? and MemberId in  (select Distinct MemberID from BillItem )
              UNION
              select distinct MemberId from FreightJournal"
        records = []
        db.fetch(sql, FREIGHT_ACCUM_START_DATE).each do |row|
          records << {:member_id => row[:memberid]}
        end
        records
      end

      def get_by_member_id
      end
    end
  end

  module FreightBenefit 
    class Repository
      def self.save member_id, records  
        db = Connection.db_teamsters
        db["DELETE FROM FreightBenefit WHERE MemberId = ?", member_id].delete
        sql = "INSERT INTO FreightBenefit ( MemberID, WeekEnding, StatusCode  ) VALUES (?, ?, ?  ) "
        records.each do |week_ending|
          db[sql,  member_id  , week_ending  , 'FB'  ].insert 
        end
      end
      def get_by_member_id
      end
    end
  end

  module Coverage

    class UncoveredWeeks

      def self.get_for_member member_id  , date_range 
        db = Connection.db_teamsters
        sql = "select A.WeekEnding  as week_ending
                            from BillingPeriodWeekEnds A 
                            LEFT OUTER JOIN (
                                select A.WeekEnding, B.PlanCode
                                from BillingPeriodWeekEnds A 
                                INNER JOIN PCMACSCoverageHistory B on A.WeekEnding between B.FromDate and B.ToDate
                                Where B.MemberId = ? and DependentId = 0 and   A.WeekEnding >= (select MIN(FromDate) from PCMACSCoverageHistory where MemberId = ?)
                            ) B on A.WeekEnding = B.WeekEnding
                            where     PlanCode is null  and   A.WeekEnding >= (select MIN(FromDate) from PCMACSCoverageHistory where MemberId =?)
                              AND A.WeekEnding between ? and ? 
                            ORDER by 1
                             "
        records = []
          db.fetch(sql, member_id, member_id, member_id , date_range.first, date_range.last).each do |row|
          records << {:week_ending => row[:week_ending].to_date}
        end
        records 
      end
    end
  end

end



class Connection
  def self.db_teamsters
    # Sequel.ado(:conn_string=>"Provider=SQLNCLI11;Server=localhost;Database=Teamsters;Uid=dbuser; Pwd=dbuser123;")
    # do postgresqlSequel.ado(:conn_string=>"Provider=SQLNCLI11;Server=localhost;Database=Teamsters;Uid=dbuser; Pwd=dbuser123;")

  end
end

# def test_insert_method
#   records = []
#   records << {:memberid => 1  ,  :company_information_id => 2000  ,  :week_starting => Date.today  ,  :amount => 34.00  ,  :is_adjustment => false  ,  :entry_type => 'contribution', :user_date => DateTime.now, :user_id => 'meirowj'}
#   records << {:memberid => 1  ,  :company_information_id => 2000  ,  :week_starting => Date.today+7  ,  :amount => 34.00  ,  :is_adjustment => false  ,  :entry_type => 'contribution', :user_date => DateTime.now, :user_id => 'meirowj'}
#   Eligibility::FreightAccumulation::Repository.save records
# end

# def test_participant_employment_history_fetch
#   Employment::EmploymentHistory::Repository.get_by_member_and_company 38109, 6368
# end


# def test_freight_benefit_insert_method
#   records = []
#   records << {:memberid => 1  ,     :weekending => Date.today  ,      :status_code => 'FB' }
#   records << {:memberid => 1  ,     :weekending => Date.today+7  ,    :status_code => 'FB' }
#   Eligibility::FreightBenefit::Repository.save records
# end

# def test_freight_guys_since_apr_2014
#   Eligibility::FreightAccumulation::Repository.freight_guys_since_apr_2014
# end 

# def test_half_pay_weeks_for_accumulation member_id
#   Eligibility::FreightAccumulation::Repository.half_pay_weeks_for_accumulation member_id
# end 


# def test_get_freight_journal member_id
#   Eligibility::FreightAccumulation::Repository.get_freight_journal member_id
# end 
# def test_get_max_billing_period_for_member member_id
#   Billing::MemberBillingInformation::Repository.get_max_billing_period_for_member member_id
# end 
# def test_uncovered_weeks member_id, date_range
#   Eligibility::Coverage::UncoveredWeeks.get_for_member member_id, date_range 
# end

# # def test_distinct_billing_periods_for_weekendings
# #   Billing::Calendar::BillingPeriod.distinct_billing_periods_for_weekendings weekendings 
# # end 



# #test_insert_method
# #pp test_participant_employment_history_fetch.collect { |x| x[:member_id] }
# #test_freight_benefit_insert_method
# #pp test_freight_guys_since_apr_2014
# #pp test_half_pay_weeks_for_accumulation 60234
# #pp test_get_freight_journal 1
# # pp test_get_max_billing_period_for_member 95419
# #test_uncovered_weeks 99439,( Date.new(2010,9,1)..Date.new(2010,9,30))
# #pp test_distinct_billing_periods_for_weekendings 




# # def test_uncovered_weeks_with_rates member_id, company_information_id ,uncovered_weeks
# #   Billing::Rates::RatesForWeeks.get_rates_for_weeks member_id, company_information_id ,uncovered_weeks
# # end

# # pp test_uncovered_weeks_with_rates 109236, 6000, [Date.new(2014,3,1), Date.new(2014,4,1), Date.new(2014,5,1)]


