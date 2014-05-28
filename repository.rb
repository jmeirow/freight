require 'sequel'
require 'date'
require 'pp'
require './money'
require_relative './daily_rate_contribution.rb'
require_relative './freight_account_entry.rb'




module Reporting

  class TableCounts

    def self.row_count table_name
      db  = Connection.db_teamsters
      sql = "SELECT count(*) as cnt FROM #{table_name} "
      cnt = 0
      db.fetch(sql) do |row|
        cnt = row[:cnt]
      end
      cnt
    end

    def self.freight_account_rows 
      row_count 'FreightAccount'
    end


    def self.freight_benefit_rows 
      row_count 'FreightBenefit'
    end


    def self.freight_statement_rows 
      row_count 'FreightStatement'
    end


    def self.balances  
      db  = Connection.db_teamsters
      sql = "
      SELECT MemberId, sum(amount) as amount 
      FROM FreightAccount 
      GROUP BY MemberId
      order by sum(amount) desc "
      results = []
      db.fetch(sql) do |row|
        record = {}
        record[:member_id] = row[:memberid]
        record[:amount] = Money.new(row[:amount])
        results << record if record[:amount].amount > 0.00
      end
      results
    end

  end

end  

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
    end   
  end   

end  



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
      def self.get_rates_for_week_ending member_id, company_information_id ,week_ending
        db = Connection.db_teamsters

        sql = "


        select PlanCode, BillingTier = TierRate, CompanyInformationId, memberId, WeekEnding,  PlanHeaderId, Amount=Convert(Money,(Rate-LotTpdAndDeathAmount))
        from  

        (
   

            select PlanCode,TierRate, CompanyInformationId, memberId, WeekEnding, Z.PlanHeaderId, LotTpdAndDeathAmount,
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
              AND BW.Weekending  = '#{week_ending.strftime('%m/%d/%Y')}' 
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
               AND BW.Weekending  = '#{week_ending.strftime('%m/%d/%Y')}'  
              GROUP BY DP.MemberID, BW.Period, BW.Weekending  
             ) KD  
            ON M.MemberID = KD.MemberID  
            AND VC.Weekending = KD.WeekEnding  
              
            WHERE (M.MemberID = #{member_id} OR M.MemberID = 0)
             AND VC.Weekending  = '#{week_ending.strftime('%m/%d/%Y')}'  
            AND C.CompanyInformationID = #{company_information_id}  
            ) Z



          INNER JOIN (
          Select PlanHeaderId, Sum(RateAmount) LotTpdAndDeathAmount 
          From MCTWFPortal.dbo.RCBenefitTypeRate rate
          INNER JOIN BenefitType  bt on bt.BenefitTypeId = rate.BenefitTypeId 
          INNER JOIN PlanDetail pd on pd.BenefitTypeID = bt.BenefitTypeId
          Where bt.BenefitId In (3, 7 , 8)
          And  '#{week_ending.strftime('%m/%d/%Y')}' between RateStartDate and RateEndDate
          group by PlanHeaderId
          ) Y on Z.PlanHeaderID = Y.PlanHeaderID
      ) A 

        "
        File.open("test.sql", "a") do |f|
          f.puts sql
        end
          record = {}        
          db.fetch(sql).each do |row| 

          record[:member_id] = row[:memberid]
          record[:company_information_id] = row[:companyinformationid]
          record[:week_starting_date] = row[:weekending].to_date - 6
          record[:amount] = Money.new(row[:amount]) 
        end
        record
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

  module FreightBenefit
    class Repository
      def self.insert_changed_member_id member_id  
        db = Connection.db_teamsters
        sql = "INSERT INTO ChangedMemberId ( MemberID, TableName, ActionCd  ) VALUES (?, 'BasicEligibilityMembers', 'U'  ) "
        db[sql, member_id ].insert 
      end

      def self.add member_id, week_ending_date
        db = Connection.db_teamsters
        sql = "INSERT INTO FreightBenefit ( MemberID, WeekEnding, StatusCode  ) VALUES (?, ?, ? ) "
        db[sql, member_id, week_ending_date, 'FB' ].insert
      end 

      def self.remove member_id, week_starting_date
      
      end

      def self.freight_benefit member_id 
        sql = "select * from FreightBenefit WHERE member_id = ? "



      end
    end
  end

  module FreightAccumulation
    class Repository

      def self.reverse_fb_week entry, description
        
        db = Connection.db_teamsters
        sql = " INSERT INTO FreightAccount (MemberId, CompanyInformationId, WeekStarting, Amount,    EntryType,   IsReversal, UserId, UserDate, Note, PlanCode ) VALUES (?, ?, ?, ?,  ?, ?, ?, ?, ?, ? ) "
        
 
        db
        [
          sql, entry.member_id  , entry.company_information_id  , 
          entry.week_starting_date   , (entry.amount.amount * -1), "#{FreightAccountEntry.coverage}" , 'Y', 'FreightBatch', 
          Time.now, description , entry.plan_code
        ].insert
      end 


      def self.add additions, entry_type  
        db = Connection.db_teamsters
        sql = " INSERT INTO FreightAccount (MemberId, CompanyInformationId, WeekStarting, Amount, EntryType, IsReversal,  UserId, UserDate ) VALUES (?, ?, ?, ?,  ?, ?, ?, ? ) "
        
        additions.each do |entry|

          db[sql, entry.member_id, entry.company_information_id, entry.week_starting_date, entry.amount.amount, entry_type , 'N', 'FreightBatch', Time.now ].insert
        end
      end


      def self.reverse deletions  
        
        db = Connection.db_teamsters
        sql = " INSERT INTO FreightAccount (MemberId, CompanyInformationId, WeekStarting, Amount,    EntryType,   IsReversal, UserId, UserDate, Note ) VALUES (?, ?, ?, ?,  ?, ?, ?, ?, ? ) "
        
         
        deletions.each do |entry|
          db[
              sql, entry.member_id  , entry.company_information_id  , entry.week_starting_date   , (entry.amount.amount * -1), "#{FreightAccountEntry.contribution}" , 
              'Y', 'FreightBatch', Time.now, 'Removed because original entry replaced in billing data.' 
            ].insert
        end
      end


      def self.half_pay_from_bbs_2012 member_id
        db = Connection.db_teamsters

        sql = "  

          select distinct MemberID, DateAdd(day,-6,WeekEnding ) WeekStarting, CompanyInformationId, UserDate = DateAdd(day,-6,WeekEnding) 
          from BasicEligibilityWeeklyHistory t1
          where EmploymentStatus = 'CH'
          and WeeklyStatus = 'BB'
          and memberid = #{member_id}
          and WeekEnding between '4/1/2012' and '3/29/2014'
          
        "
        records = []
        db.fetch(sql   ).each do |row|
          hash = Hash.new
          hash[:member_id] = row[:memberid]
          hash[:week_starting_date] = row[:weekstarting].to_date
          hash[:company_information_id] = row[:companyinformationid]
          hash[:user_date] =  row[:weekstarting].to_date
          hash[:amount] = Money.new(34.00)
          records << DailyRateContribution.new(hash)   
        end
        records
      end


      def self.half_pay_weeks  member_id , allocation_period
        db = Connection.db_teamsters
        sql = "          
          SELECT distinct DateAdd(DAY,-6,WeekEnding) WeekStarting, CompanyInformationId 
          FROM BillingPeriodWeekEnds A
          INNER JOIN ParticipantEmploymentHistory B on A.WeekEnding between b.FromDate and b.ToDate
          WHERE WeekEnding  between ? and  ?
          AND EmploymentStatus = 'CH'
          AND memberid = ?  "


        
        records = []
        db.fetch(sql, allocation_period.first, allocation_period.last, member_id  ).each do |row|
          hash = Hash.new
          hash[:member_id] = member_id
          hash[:week_starting_date] = row[:weekstarting].to_date
          hash[:user_date] =  row[:weekstarting].to_date
          hash[:company_information_id] = row[:companyinformationid]
          hash[:amount] = Money.new(34.00)
          records << DailyRateContribution.new(hash)            
        end
        records
      end

    
      def self.get_freight_account member_id 
        db = Connection.db_teamsters
        sql = "SELECT  TxnId, MemberId , CompanyInformationId , WeekStarting ,Amount , EntryType, UserDate   
        from FreightAccount where MemberID = ?"
        records = []
        db.fetch(sql, member_id).each do |row|
          hash = Hash.new
          hash[:txn_id] = row[:txnid]
          hash[:member_id] = row[:memberid]
          hash[:week_starting_date] = row[:weekstarting].to_date
          hash[:company_information_id] = row[:companyinformationid]
          hash[:user_date] = row[:userdate].to_date
          hash[:entry_type] =  row[:entrytype]
          hash[:amount] = Money.new(row[:amount])
          records << FreightAccountEntry.new(hash)        
        end
        records
      end


      def self.freight_member_ids
        db = Connection.db_teamsters
        sql = "

              -- INITIAL PERIOD WHERE CH w/ BB COUNTED AS CONTRIBUTION
                select t1.MemberId 
                from BasicEligibilityWeeklyHistory t1
                where EmploymentStatus = 'CH'
                and WeeklyStatus = 'BB'
                and WeekEnding between '4/1/2012' and '3/29/2014'

 
              UNION

              -- ANYTIME AFTER INITIAL PERIOD 
              SELECT DISTINCT MemberId 
              FROM ParticipantEmploymentHistory 
              WHERE EmploymentStatus = 'CH' 
              AND ToDate >= '3/30/2014'  
              UNION



              -- MEMBERS ALREADY IN FREIGHT ACCOUNT
              SELECT DISTINCT MemberId FROM FreightAccount


              "

        records = []
        db.fetch(sql).each do |row|
          records <<  row[:memberid] 
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

    class Repository

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


      def self.get_covered_weeks member_id  , week_starting_dates
        puts "Called from get_covered_weeks"
        pp week_starting_dates
        puts "======================"



        week_ending_dates = week_starting_dates.collect{|x| x + 6 }
        db = Connection.db_teamsters
        sql = "SELECT A.WeekEnding
                FROM BillingPeriodWeekEnds A 
                INNER JOIN PCMACSCoverageHistory B ON A.WeekEnding BETWEEN B.FromDate AND B.ToDate
                WHERE B.MemberId = ? AND DependentId = 0 AND   A.WeekEnding  in (?)
                ORDER by 1 "


        records = []
          db.fetch(sql, member_id,  week_ending_dates.join(",")).each do |row|
          records <<  row[:weekending].to_date - 6 
        end
        records 
      end


      def self.is_covered? member_id  , week_starting_date
        db = Connection.db_teamsters
        sql = " 
                SELECT count(*) as cnt   
                FROM PCMACSCoverageHistory  
                WHERE  MemberId = ? AND DependentId = 0 AND   ? BETWEEN  FromDate AND  ToDate
                 "
        count = 0
        db.fetch(sql, member_id,  week_starting_date).each do |row|
          count = row[:cnt]
        end
        return count > 0 
      end

    end
  end

end



class Connection
  def self.db_teamsters
    Sequel.ado(:conn_string=>"Provider=SQLNCLI11;Server=localhost;Database=Teamsters;Uid=dbuser; Pwd=dbuser123;")
  end
end
 
