class GuamVillageMapper
  # Comprehensive mapping of Guam villages with both English and Chamorro names
  # Each entry maps to a canonical name that Google Maps recognizes
  VILLAGE_MAPPINGS = {
    # Agat / Hagat
    'agat' => {
      canonical: 'Agat',
      alternatives: ['hagat', 'agat'],
      zip_codes: ['96915'],
      coordinates: [13.3833, 144.6500]
    },
    
    # Agana / Hagatna / Hagåtña
    'agana' => {
      canonical: 'Hagåtña',
      alternatives: ['agana', 'hagatna', 'hagåtña', 'hagatña'],
      zip_codes: ['96910'],
      coordinates: [13.4745, 144.7504]
    },
    
    # Asan
    'asan' => {
      canonical: 'Asan',
      alternatives: ['asan', 'åsan'],
      zip_codes: ['96910'],
      coordinates: [13.4667, 144.7167]
    },
    
    # Barrigada / Barigåda
    'barrigada' => {
      canonical: 'Barrigada',
      alternatives: ['barrigada', 'barigåda', 'barigada'],
      zip_codes: ['96913'],
      coordinates: [13.4667, 144.8000]
    },
    
    # Chalan Pago / Chalan Pågu
    'chalan_pago' => {
      canonical: 'Chalan Pago',
      alternatives: ['chalan pago', 'chalan pågu', 'chalan-pago', 'chalanpago'],
      zip_codes: ['96910'],
      coordinates: [13.4500, 144.7833]
    },
    
    # Dededo / Dedidu
    'dededo' => {
      canonical: 'Dededo',
      alternatives: ['dededo', 'dedidu'],
      zip_codes: ['96929', '96912'],
      coordinates: [13.5167, 144.8333]
    },
    
    # Inarajan / Inalåhan
    'inarajan' => {
      canonical: 'Inarajan',
      alternatives: ['inarajan', 'inalåhan', 'inalahan'],
      zip_codes: ['96915'],
      coordinates: [13.2833, 144.7500]
    },
    
    # Mangilao
    'mangilao' => {
      canonical: 'Mangilao',
      alternatives: ['mangilao'],
      zip_codes: ['96913'],
      coordinates: [13.4500, 144.8000]
    },
    
    # Merizo / Malesso'
    'merizo' => {
      canonical: 'Merizo',
      alternatives: ['merizo', "malesso'", 'malesso'],
      zip_codes: ['96915'],
      coordinates: [13.2667, 144.6667]
    },
    
    # Mongmong
    'mongmong' => {
      canonical: 'Mongmong',
      alternatives: ['mongmong', 'mongmong-toto-maite'],
      zip_codes: ['96910'],
      coordinates: [13.4333, 144.7667]
    },
    
    # Ordot
    'ordot' => {
      canonical: 'Ordot',
      alternatives: ['ordot', 'chalan pago-ordot'],
      zip_codes: ['96910'],
      coordinates: [13.4333, 144.7833]
    },
    
    # Piti
    'piti' => {
      canonical: 'Piti',
      alternatives: ['piti'],
      zip_codes: ['96915'],
      coordinates: [13.4500, 144.6833]
    },
    
    # Santa Rita
    'santa_rita' => {
      canonical: 'Santa Rita',
      alternatives: ['santa rita', 'santa-rita', 'santarita'],
      zip_codes: ['96915'],
      coordinates: [13.3833, 144.6333]
    },
    
    # Sinajana / Sinahåña
    'sinajana' => {
      canonical: 'Sinajana',
      alternatives: ['sinajana', 'sinahåña', 'sinahana'],
      zip_codes: ['96910'],
      coordinates: [13.4500, 144.7500]
    },
    
    # Talofofo / Talo'fo'fo'
    'talofofo' => {
      canonical: 'Talofofo',
      alternatives: ['talofofo', "talo'fo'fo'", 'talofofo'],
      zip_codes: ['96915'],
      coordinates: [13.3500, 144.7333]
    },
    
    # Tamuning / Tamuneng
    'tamuning' => {
      canonical: 'Tamuning',
      alternatives: ['tamuning', 'tamuneng', 'tumon'],
      zip_codes: ['96913', '96911'],
      coordinates: [13.4833, 144.7833]
    },
    
    # Toto
    'toto' => {
      canonical: 'Toto',
      alternatives: ['toto'],
      zip_codes: ['96910'],
      coordinates: [13.4167, 144.7500]
    },
    
    # Umatac / Humåtak
    'umatac' => {
      canonical: 'Umatac',
      alternatives: ['umatac', 'humåtak', 'humatak'],
      zip_codes: ['96915'],
      coordinates: [13.3000, 144.6667]
    },
    
    # Yigo / Yigu
    'yigo' => {
      canonical: 'Yigo',
      alternatives: ['yigo', 'yigu'],
      zip_codes: ['96929'],
      coordinates: [13.5333, 144.8833]
    },
    
    # Yona
    'yona' => {
      canonical: 'Yona',
      alternatives: ['yona'],
      zip_codes: ['96914'],
      coordinates: [13.4167, 144.8167]
    }
  }.freeze

  # Create a reverse lookup for quick searching
  VILLAGE_LOOKUP = begin
    lookup = {}
    VILLAGE_MAPPINGS.each do |key, data|
      data[:alternatives].each do |alt|
        lookup[alt.downcase.gsub(/[^a-z0-9\s]/, '').gsub(/\s+/, ' ').strip] = key
      end
    end
    lookup
  end.freeze

  class << self
    # Find the canonical village name from any variation
    def find_canonical_village(input_village)
      return nil if input_village.blank?
      
      # Normalize input: lowercase, remove special chars, normalize spaces
      normalized = input_village.to_s.downcase.gsub(/[^a-z0-9\s]/, '').gsub(/\s+/, ' ').strip
      
      # Direct lookup
      village_key = VILLAGE_LOOKUP[normalized]
      return VILLAGE_MAPPINGS[village_key][:canonical] if village_key
      
      # Fuzzy matching for partial matches
      find_fuzzy_match(normalized)
    end

    # Get all alternative names for a village
    def get_alternatives(canonical_name)
      village_data = VILLAGE_MAPPINGS.values.find { |data| data[:canonical] == canonical_name }
      village_data ? village_data[:alternatives] : []
    end

    # Validate if a village name is recognized
    def valid_village?(village_name)
      find_canonical_village(village_name).present?
    end

    # Get suggested corrections for invalid village names
    def suggest_corrections(input_village, limit: 3)
      return [] if input_village.blank?
      
      normalized = input_village.to_s.downcase.gsub(/[^a-z0-9\s]/, '').gsub(/\s+/, ' ').strip
      suggestions = []
      
      # Find villages that contain the input or vice versa
      VILLAGE_MAPPINGS.each do |key, data|
        data[:alternatives].each do |alt|
          alt_normalized = alt.downcase.gsub(/[^a-z0-9\s]/, '').gsub(/\s+/, ' ').strip
          
          # Check for substring matches
          if alt_normalized.include?(normalized) || normalized.include?(alt_normalized)
            suggestions << {
              original: input_village,
              suggestion: data[:canonical],
              confidence: calculate_similarity(normalized, alt_normalized)
            }
          end
        end
      end
      
      # Sort by confidence and return top suggestions
      suggestions.sort_by { |s| -s[:confidence] }.first(limit)
    end

    # Normalize an address by replacing village names with canonical versions
    def normalize_address(address)
      return address if address.blank?
      
      # Handle both hash and string inputs
      case address
      when Hash
        # For hash inputs, normalize the city field specifically
        normalized_hash = address.dup
        city_field = normalized_hash[:city] || normalized_hash['city']
        
        if city_field.present?
          canonical_city = find_canonical_village(city_field)
          if canonical_city && canonical_city != city_field
            # Update both symbol and string keys if present
            normalized_hash[:city] = canonical_city if normalized_hash.key?(:city)
            normalized_hash['city'] = canonical_city if normalized_hash.key?('city')
            Rails.logger.info "Village name normalized: '#{city_field}' → '#{canonical_city}' in address: #{address}"
          end
        end
        
        return normalized_hash
      when String
        # For string inputs, try to find and replace village names
        normalized_address = address.dup
      else
        # Convert to string and process
        normalized_address = address.to_s.dup
      end
      
      VILLAGE_MAPPINGS.each do |key, data|
        data[:alternatives].each do |alt|
          # Create regex pattern for the alternative name
          pattern = /\b#{Regexp.escape(alt)}\b/i
          
          if normalized_address.match?(pattern)
            normalized_address.gsub!(pattern, data[:canonical])
            Rails.logger.info "Village name normalized: '#{alt}' → '#{data[:canonical]}' in address: #{address}"
            break # Only replace the first match to avoid over-replacement
          end
        end
      end
      
      normalized_address
    end

    # Get zip code suggestions for a village
    def get_zip_codes(village_name)
      canonical = find_canonical_village(village_name)
      return [] unless canonical
      
      village_data = VILLAGE_MAPPINGS.values.find { |data| data[:canonical] == canonical }
      village_data ? village_data[:zip_codes] : []
    end

    # Get coordinates for a village (for fallback geocoding)
    def get_coordinates(village_name)
      canonical = find_canonical_village(village_name)
      return nil unless canonical
      
      village_data = VILLAGE_MAPPINGS.values.find { |data| data[:canonical] == canonical }
      village_data ? village_data[:coordinates] : nil
    end

    # Validate address format and suggest improvements
    def validate_and_suggest(address_components)
      suggestions = {}
      
      # Handle both string and symbol keys
      city_field = address_components[:city] || address_components['city']
      
      if city_field.present?
        canonical_city = find_canonical_village(city_field)
        if canonical_city && canonical_city != city_field
          suggestions[:city] = {
            original: city_field,
            suggested: canonical_city,
            reason: "Using standard village name"
          }
        elsif !valid_village?(city_field)
          corrections = suggest_corrections(city_field)
          if corrections.any?
            suggestions[:city] = {
              original: city_field,
              suggested: corrections.first[:suggestion],
              reason: "Did you mean '#{corrections.first[:suggestion]}'?"
            }
          end
        end
      end
      
      # Skip zip code validation - Guam zip codes are complex and not always straightforward
      
      suggestions
    end

    private

    def find_fuzzy_match(normalized_input)
      best_match = nil
      best_score = 0.0
      
      VILLAGE_MAPPINGS.each do |key, data|
        data[:alternatives].each do |alt|
          alt_normalized = alt.downcase.gsub(/[^a-z0-9\s]/, '').gsub(/\s+/, ' ').strip
          score = calculate_similarity(normalized_input, alt_normalized)
          
          if score > best_score && score > 0.6 # Minimum similarity threshold
            best_score = score
            best_match = data[:canonical]
          end
        end
      end
      
      best_match
    end

    def calculate_similarity(str1, str2)
      return 1.0 if str1 == str2
      return 0.0 if str1.empty? || str2.empty?
      
      # Simple Jaccard similarity
      set1 = str1.split('').to_set
      set2 = str2.split('').to_set
      
      intersection = set1 & set2
      union = set1 | set2
      
      intersection.size.to_f / union.size.to_f
    end
  end
end
