class Api::V1::AddressValidationController < ApplicationController
  # Skip authentication for village suggestions (public endpoint)
  skip_before_action :authenticate_user!, only: [:village_suggestions]
  # POST /api/v1/address_validation/validate
  def validate
    address_components = validation_params
    
    # Validate and get suggestions using GuamVillageMapper
    suggestions = GuamVillageMapper.validate_and_suggest(address_components)
    
    # Check if city is a valid Guam village
    city_valid = GuamVillageMapper.valid_village?(address_components[:city])
    
    # Get canonical village name if valid
    canonical_city = GuamVillageMapper.find_canonical_village(address_components[:city])
    
    # Get zip code suggestions if city is valid
    suggested_zip_codes = canonical_city ? GuamVillageMapper.get_zip_codes(canonical_city) : []
    
    render json: {
      valid: suggestions.empty? && city_valid,
      suggestions: suggestions,
      city_info: {
        valid: city_valid,
        canonical: canonical_city,
        suggested_zip_codes: suggested_zip_codes
      }
    }
  end

  # GET /api/v1/address_validation/village_suggestions?query=agat
  def village_suggestions
    query = params[:query].to_s.strip
    
    if query.length < 2
      render json: { suggestions: [] }
      return
    end
    
    # Get suggestions from GuamVillageMapper
    suggestions = GuamVillageMapper.suggest_corrections(query, limit: 5)
    
    # Also include exact matches and partial matches
    all_villages = GuamVillageMapper::VILLAGE_MAPPINGS.values.map { |data| data[:canonical] }.uniq
    
    # Find villages that start with or contain the query
    matching_villages = all_villages.select do |village|
      village.downcase.include?(query.downcase)
    end.first(5)
    
    # Combine and deduplicate
    combined_suggestions = (suggestions.map { |s| s[:suggestion] } + matching_villages).uniq.first(5)
    
    render json: {
      query: query,
      suggestions: combined_suggestions.map do |village|
        {
          name: village,
          zip_codes: GuamVillageMapper.get_zip_codes(village),
          alternatives: GuamVillageMapper.get_alternatives(village)
        }
      end
    }
  end

  # POST /api/v1/address_validation/normalize
  def normalize
    address = params[:address].to_s.strip
    
    if address.blank?
      render json: { error: 'Address is required' }, status: :bad_request
      return
    end
    
    # Normalize the address using GuamVillageMapper
    normalized_address = GuamVillageMapper.normalize_address(address)
    
    render json: {
      original_address: address,
      normalized_address: normalized_address,
      changed: normalized_address != address
    }
  end

  private

  def validation_params
    params.require(:address).permit(:street_address, :city, :state, :zip_code, :apartment_unit)
  end
end
