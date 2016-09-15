require 'pry'
require_relative 'district_repository'
require_relative 'sanitizer'

class HeadcountAnalyst
  attr_accessor :dr, :rate_trend

  def initialize(district_repository)
    @dr = district_repository
    @rate_trend = {}
  end

  def kindergarten_participation_rate_variation(district, location)
    name = location[:against]
    district_average = find_average_kindergarten_participation(district)
    location_average = find_average_kindergarten_participation(name)
    Sanitizer.truncate(district_average/location_average)
  end

  def high_school_participation_rate_variation(district, location)
    name = location[:against]
    district_average = find_average_high_school_participation(district)
    location_average = find_average_high_school_participation(name)
    Sanitizer.truncate(district_average/location_average)
  end

  def find_average_kindergarten_participation(name)
    results = @dr.enrollment.enrollments[name].kindergarten_participation.values
    average = results.reduce(0) {|sum, rate| sum += rate}.to_f / results.size
    Sanitizer.truncate(average)
  end

  def find_average_high_school_participation(name)
    results = @dr.enrollment.enrollments[name].high_school_graduation_participation.values
    average = results.reduce(0) {|sum, rate| sum += rate}.to_f / results.size
    Sanitizer.truncate(average)
  end

  def kindergarten_participation_rate_variation_trend(district, location)
    name = location[:against]
    build_variation_trend_hash(district, name, true)
  end

  def kindergarten_participation_against_high_school_graduation(district)
    kindergarten_variation = kindergarten_participation_rate_variation(district, :against => "COLORADO")
    graduation_variation = high_school_participation_rate_variation(district, :against => "COLORADO")

    if graduation_variation == 0
      0
    else
      Sanitizer.truncate(kindergarten_variation / graduation_variation)
    end

  end

  def kindergarten_participation_correlates_with_high_school_graduation(location)
    name = location.values.reduce

    if name.class == Array
      name.each {|loc| calculate_correlation(loc) }
    elsif name.upcase != 'STATEWIDE'
      calculate_correlation(name)
    else
      calculate_percentage_correlated
    end
  end

  def calculate_correlation(name)
    variation = kindergarten_participation_against_high_school_graduation(name)
    if  variation.between?(0.6, 1.5)
      true
    else
      false
    end
  end

  def calculate_percentage_correlated
    d = @dr.districts.keys
    counter = 0
    d.each do |district|
      counter += 1 if calculate_correlation(district)
    end
    counter.to_f / d.length.to_f >= 0.70 ? true : false
  end

  def build_variation_trend_hash(district, location, first_run)
    if first_run
      assign_hash_values(district, true)
      build_variation_trend_hash(district, location, false)
    else
      assign_hash_values(location, false)
    end
    @rate_trend.sort.to_h
  end

  def assign_hash_values(input, first_object)
    results = @dr.enrollment.enrollments[input].kindergarten_participation
    results.each do |key, value|
      if first_object
        @rate_trend[key] = value
      else
        @rate_trend[key] = Sanitizer.truncate(@rate_trend[key] / value)
      end
    end
  end

end
