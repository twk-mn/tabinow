class ItinerariesController < ApplicationController
  before_action :set_itinerary, except: %i[index new create]
  skip_before_action :authenticate_user!, only: :create

  def index
    @itineraries = policy_scope(Itinerary)
    @itinerary = Itinerary.new
  end

  def show
    @day = @itinerary.days[params[:day].to_i - 1]
    @contents = params[:query].present? ? Content.where('location ILIKE ?', "%#{params[:query]}%") : []
  end

  def new
    @itinerary = Itinerary.new
    authorize @itinerary
  end

  def create
    set_new_itinerary
    if @itinerary.save
      set_new_day
      set_employee
    elsif user_signed_in?
      @itineraries = policy_scope(Itinerary)
      flash[:alert] = @itinerary.errors.full_messages.first
      render :index, status: :unprocessable_entity
    else
      flash[:alert] = @itinerary.errors.full_messages.first
      render 'pages/home', status: :unprocessable_entity
    end
  end

  def update
    @itinerary.update(itineraries_params)
    redirect_to itinerary_path(@itinerary)
  end

  def destroy
    # Night not be necessary
    @itinerary.destroy
    redirect_to itineraries_path
  end

  def send_draft
    # Sending draft to the client for feedback.
  end

  def draft
    # Client can give my feedback on the itinerary.
  end

  def payment
    # Client can make the payment
  end

  def send_confirmation
    # Client gets a confirmation email with a pdf of the booked itinerary
  end

  private

  def set_new_day
    return unless @itinerary.save

    @days = params[:number_of_days].present? ? params[:number_of_days].to_i : @itinerary.total_days
    @days.times do |i|
      day = Day.new(number: i + 1)
      day.itinerary = @itinerary
      day.save!
      new_category_and_item("Accommodation", day)
      new_category_and_item("Restaurant", day)
      new_category_and_item("Activity", day)
    end
  end

  def new_category_and_item(item_category, day)
    if item_category == "Accommodation"
      category = Category.new(title: "Accommodation",
                              sub_category: "Not Set",
                              day:)
      if category.save!
        # set_accommodation
        AccommodationApiJob.perform_later(itineraries_params, min_price_generator, max_price_generator, @itinerary, category) # <- The job is queued
      end
    elsif item_category == "Restaurant"
      food_times = ["Lunch", "Dinner"]
      food_times.each do |food_time|
        category = Category.new(title: "Restaurant",
                                sub_category: food_time,
                                day:)
        if category.save!
          RestaurantApiJob.perform_later(food_time, max_price_generator, @itinerary, category) # <- The job is queued
        end
      end
    else
      2.times do
        category = Category.new(title: "Activity",
                                sub_category: "Not Set",
                                day:)
        if category.save!
          ActivityApiJob.perform_later(max_price_generator, @itinerary, category) # <- The job is queued
        end
      end
    end
  end

  def min_price_generator
    min_price = @itinerary.min_budget.to_i
    return min_price
  end

  def max_price_generator
    max_price = @itinerary.max_budget.to_i
    return max_price
  end

  def set_activity
    activity_budget = max_price_generator / 6
    set_activity_budget = []

    if activity_budget >= 60
      set_activity_budget = "1, 2, 3, 4"
    elsif activity_budget >= 30 && activity_budget < 60
      set_activity_budget = "1, 2, 3"
    elsif activity_budget >= 10 && activity_budget < 30
      set_activity_budget = "1, 2"
    else
      set_activity_budget = "1"
    end

    activities = ActivityApiService.new(location: params[:location],
                                        keyword: "activities",
                                        number_people: params[:number_people],
                                        price: set_activity_budget)

    begin
      activities_results = activities.call
      activity_selected = activities_results.sample
    rescue StandardError
      retry
    end

    activity_selected["location"]["display_address"].nil? ? activity_location = location : activity_location = activity_selected["location"]["display_address"].first

    Content.create!(name: activity_selected["name"],
                    price: set_yelp_price(activity_selected["price"]),
                    location: activity_location,
                    rating: activity_selected["rating"],
                    category: Category.last,
                    description: activity_selected["categories"].first["title"],
                    api: "",
                    status: 0)
  end

  def set_itinerary
    @itinerary = Itinerary.find(params[:id])
    authorize @itinerary
  end

  def set_new_itinerary
    @itinerary = Itinerary.new(itineraries_params)
    @days = params[:number_of_days].present? ? params[:number_of_days].to_i : @itinerary.total_days
    title = "#{@days} in #{itineraries_params[:location].capitalize}"
    @itinerary.title = title
    set_new_client
    authorize @itinerary
  end

  def set_new_client
    return unless
     params[:email]

    generic_password = "tabinow"
    client = User.where(email: params[:email]).first_or_initialize
    client.name = params[:name]
    client.password = generic_password unless client.id
    client.save
    @itinerary.client = client
    @itinerary
  end

  def set_employee
    if user_signed_in?
      @itinerary.employee = current_user
      redirect_to itinerary_path(@itinerary)
    else
      redirect_to root_path
      flash[:success] = "Request sent!"
    end
  end

  def itineraries_params
    params.require(:itinerary).permit(:name, :title, :location, :status, :employee_id, :client_id, :max_budget, :min_budget,
                                      :special_request, :start_date, :end_date, :archived)
  end
end
