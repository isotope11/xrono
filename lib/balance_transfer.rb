class BalanceTransfer

  def initialize(distribution_manager=DistributionManager.new)
    @distribution_manager = distribution_manager
  end 

  def run
    User.all.each do |user|
      check_time(user)
      10_day_assessment(user)
      award_pto(user)
    end
  end

  def check_time(user)
    # daily time must be put in before 11:59pm current day.
    # daily time put in must = 8 hours.
    # time not put in each day && >= 8:
    # do not receive $10 per diem
    # $25 demerrit fee assessed
    date = (Time.now - 24.hours)
    if user.hours_entered_for_day(Time.now) < 8
      issue_demerit(user)
    else
      award_per_diem(user)
    end
    
    add_time_to_offset(user)
  end

  def 10_day_assessment(user)
    # sliding window of 10 days:
    # if 70+ external hours are billed: +1 Remote work day (RWD)
    window = (Date.today - 10.days)
    if external_hours > 70
      award_remote_day(user)
    end
  end

  def sum_hours(method, hours)
    hours.select{|wu| wu.send(method) }.sum(&:hours)
  end

  def external_hours_for_user(user, options = {}) 
    end_date, start_date  = Date.today, (Date.today - 10.days)
    final_array = []
    (start_date..end_date).each do |i_date| 
      _beg, _end = i_date.beginning_of_day, i_date.end_of_day
      hours = WorkUnit.for_user(user).scheduled_between(_beg,_end).all
      final_array << [sum_hours(:external?, hours).to_f]
    end
    final_array.flatten.sum 
  end 

  def award_per_diem(user)
    # per diem bonus is incremented + $10
    @distribution_manager.issue_per_diem_to_user user, 10
  end

  def add_time_to_offset(user)
    if user.hours_entered_for_day(Time.now) > 8
      @time = user.hours_entered_for_day(Time.now) - 8
    end
    @distribution_manager.issue_time_to_offset user, @time
  end

  def award_pto(user)
    # for every 40 hours over offset +1 PTO
    if user.offset_account.balance > 40
      until user.offset_account.balance < 40
        @distribution_manager.deduct_time_from_offset user, 40
        @distribution_manager.issue_pto_to_user user, 1
      end
    end
  end

  def award_remote_day(user)
    @distribution_manager.issue_remote_day_to_user user, 1
  end

  def issue_demerit(user)
    @distribution_manager.issue_demerit_fee_to_user user, 25
  end

  # show total per diem bonus earned
  # PDB (Per diem bonus) will be in the state of qualified or non-qualified.
  # qualified if offset > -1
  # non-qualified if offset < 0
  # suggest making PDB balance field green or red showing qualifying state.

end
