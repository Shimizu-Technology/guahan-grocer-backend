class OpenFoodFactsService
  BASE_URL = 'https://world.openfoodfacts.org/api/v0/product'
  SEARCH_URL = 'https://world.openfoodfacts.org/cgi/search.pl'

  def self.fetch_by_gtin(gtin)
    return nil if gtin.blank?

    begin
      Rails.logger.info "🌐 Fetching from Open Food Facts: #{gtin}"
      
      response = HTTParty.get(
        "#{BASE_URL}/#{gtin}.json",
        headers: {
          'User-Agent' => 'GuahanGrocer-App-1.0 - https://guahangrocer.com',
          'Accept' => 'application/json'
        },
        timeout: 10
      )
      
      Rails.logger.info "📡 Open Food Facts response: status=#{response.code}, body_status=#{response.parsed_response&.dig('status')}"
      
      if response.success? && response.parsed_response['status'] == 1
        product_data = parse_product_data(response.parsed_response['product'])
        Rails.logger.info "✅ Product found: #{product_data[:name]}"
        product_data
      else
        status_verbose = response.parsed_response&.dig('status_verbose') || 'unknown error'
        Rails.logger.info "❌ Product not found: #{status_verbose}"
        nil
      end
    rescue => e
      Rails.logger.error "💥 OpenFoodFacts API error: #{e.message}"
      nil
    end
  end

  def self.search_by_name(product_name, brand = nil, limit = 10)
    return nil if product_name.blank?

    begin
      # Build search query
      search_terms = []
      search_terms << product_name.strip
      search_terms << brand.strip if brand.present?
      
      search_query = search_terms.join(' ')
      
      Rails.logger.info "🔍 Searching Open Food Facts for: '#{search_query}'"
      
      # Search parameters
      params = {
        search_terms: search_query,
        search_simple: 1,
        action: 'process',
        json: 1,
        page_size: limit,
        sort_by: 'popularity'  # Sort by popularity to get better matches first
      }
      
      response = HTTParty.get(
        SEARCH_URL,
        query: params,
        headers: {
          'User-Agent' => 'GuahanGrocer-App-1.0 - https://guahangrocer.com',
          'Accept' => 'application/json'
        },
        timeout: 15
      )
      
      Rails.logger.info "📡 Open Food Facts search response: status=#{response.code}"
      
      if response.success? && response.parsed_response['products']
        products = response.parsed_response['products']
        Rails.logger.info "🔍 Found #{products.length} potential matches"
        
        # Parse and score the results
        candidates = products.map do |product_data|
          parsed_data = parse_product_data(product_data)
          next nil unless parsed_data
          
          # Calculate match score
          score = calculate_match_score(product_name, brand, parsed_data)
          parsed_data.merge(match_score: score)
        end.compact
        
        # Sort by match score and return best matches
        best_matches = candidates.sort_by { |c| -c[:match_score] }
        
        if best_matches.any?
          Rails.logger.info "✅ Best match: #{best_matches.first[:name]} (score: #{best_matches.first[:match_score]})"
          best_matches
        else
          Rails.logger.info "❌ No suitable matches found"
          nil
        end
      else
        Rails.logger.info "❌ Search failed or no results"
        nil
      end
    rescue => e
      Rails.logger.error "💥 OpenFoodFacts search error: #{e.message}"
      nil
    end
  end

  def self.find_best_match(product_name, brand = nil)
    results = search_by_name(product_name, brand, 5)
    return nil unless results&.any?
    
    # Return the best match if it has a reasonable score
    best_match = results.first
    if best_match[:match_score] >= 0.3  # Minimum threshold for accepting a match
      Rails.logger.info "🎯 Accepting best match: #{best_match[:name]} (score: #{best_match[:match_score]})"
      best_match
    else
      Rails.logger.info "🚫 Best match score too low: #{best_match[:match_score]}"
      nil
    end
  end

  private

  def self.parse_product_data(product_data)
    return nil if product_data.blank?

    {
      # Basic product info
      gtin: product_data['code'],
      name: clean_text(product_data['product_name'] || product_data['product_name_en']),
      brand: clean_text(product_data['brands']),
      size: clean_text(product_data['quantity']),
      description: clean_text(product_data['ingredients_text'] || product_data['ingredients_text_en']),
      
      # Enhanced fields
      serving_size: clean_text(product_data['serving_size']),
      ingredients_text: clean_text(product_data['ingredients_text'] || product_data['ingredients_text_en']),
      
      # Safety info
      allergens: clean_allergens(product_data['allergens']),
      traces: clean_allergens(product_data['traces']),
      
      # Classification
      off_categories: clean_text(product_data['categories']),
      off_labels: clean_text(product_data['labels']),
      
      # Health scores
      nutriscore_grade: clean_nutriscore(product_data['nutriscore_grade']),
      nova_group: product_data['nova_group']&.to_i,
      
      # Images
      image_urls: extract_image_urls(product_data),
      image_ingredients_url: clean_text(product_data['image_ingredients_url']),
      image_nutrition_url: clean_text(product_data['image_nutrition_url']),
      
      # Environmental
      packaging: clean_text(product_data['packaging']),
      
      # Nutrition data (existing)
      nutrition_data: extract_nutrition_data(product_data)
    }
  end

  def self.clean_text(text)
    return nil if text.blank?
    text.to_s.strip.presence
  end

  def self.clean_nutriscore(grade)
    return nil if grade.blank?
    cleaned = grade.to_s.strip.downcase
    # Only accept valid Nutri-Score grades (A, B, C, D, E)
    if %w[a b c d e].include?(cleaned)
      cleaned.upcase
    else
      # Invalid or unknown grades become nil
      nil
    end
  end

  def self.clean_allergens(allergens_text)
    return nil if allergens_text.blank?
    
    # Split by comma and clean each allergen
    allergens = allergens_text.split(',').map do |allergen|
      cleaned = allergen.strip
      
      # Remove language prefixes like "en:", "fr:", etc.
      cleaned = cleaned.gsub(/^[a-z]{2}:/, '')
      
      # Remove underscores and convert to readable format
      cleaned = cleaned.gsub('_', ' ')
      
      # Capitalize first letter of each word
      cleaned.split(' ').map(&:capitalize).join(' ')
    end
    
    # Join with commas and return
    allergens.reject(&:blank?).join(', ')
  end

  def self.extract_image_urls(product_data)
    urls = []
    
    # Main product image
    if product_data['image_url'].present?
      urls << product_data['image_url']
    end
    
    # Front image
    if product_data['image_front_url'].present?
      urls << product_data['image_front_url']
    end
    
    # Ingredients image
    if product_data['image_ingredients_url'].present?
      urls << product_data['image_ingredients_url']
    end
    
    # Nutrition image
    if product_data['image_nutrition_url'].present?
      urls << product_data['image_nutrition_url']
    end
    
    urls.uniq.compact
  end

  def self.extract_nutrition_data(product_data)
    return {} unless product_data['nutriments'].present?

    nutriments = product_data['nutriments']
    
    {
      energy_kcal_100g: nutriments['energy-kcal_100g'],
      energy_kj_100g: nutriments['energy-kj_100g'],
      fat_100g: nutriments['fat_100g'],
      saturated_fat_100g: nutriments['saturated-fat_100g'],
      carbohydrates_100g: nutriments['carbohydrates_100g'],
      sugars_100g: nutriments['sugars_100g'],
      fiber_100g: nutriments['fiber_100g'],
      proteins_100g: nutriments['proteins_100g'],
      salt_100g: nutriments['salt_100g'],
      sodium_100g: nutriments['sodium_100g'],
      ingredients_text: product_data['ingredients_text'],
      allergens: product_data['allergens'],
      categories: product_data['categories'],
      labels: product_data['labels']
    }.compact
  end

  def self.calculate_match_score(target_name, target_brand, candidate)
    score = 0.0
    
    # Name similarity (most important - 60% weight)
    if candidate[:name].present?
      name_similarity = string_similarity(target_name.downcase, candidate[:name].downcase)
      score += name_similarity * 0.6
    end
    
    # Brand similarity (30% weight)
    if target_brand.present? && candidate[:brand].present?
      brand_similarity = string_similarity(target_brand.downcase, candidate[:brand].downcase)
      score += brand_similarity * 0.3
    elsif target_brand.blank? && candidate[:brand].present?
      # Slight bonus for having brand info when we don't
      score += 0.1
    end
    
    # Bonus for having rich data (10% weight)
    data_richness = 0.0
    data_richness += 0.2 if candidate[:allergens].present?
    data_richness += 0.2 if candidate[:ingredients_text].present?
    data_richness += 0.2 if candidate[:nutrition_data].present? && candidate[:nutrition_data].any?
    data_richness += 0.2 if candidate[:nutriscore_grade].present?
    data_richness += 0.2 if candidate[:image_urls].present? && candidate[:image_urls].any?
    
    score += [data_richness, 1.0].min * 0.1
    
    # Ensure score is between 0 and 1
    [score, 1.0].min
  end

  def self.string_similarity(str1, str2)
    return 0.0 if str1.blank? || str2.blank?
    return 1.0 if str1 == str2
    
    # Simple word-based similarity
    words1 = str1.split(/\s+/).map(&:strip).reject(&:blank?)
    words2 = str2.split(/\s+/).map(&:strip).reject(&:blank?)
    
    return 0.0 if words1.empty? || words2.empty?
    
    # Calculate Jaccard similarity (intersection over union)
    intersection = (words1 & words2).length
    union = (words1 | words2).length
    
    return 0.0 if union == 0
    intersection.to_f / union.to_f
  end
end
