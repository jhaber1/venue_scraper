import Tirexs.{HTTP, Search, Query}
# import UUID

defmodule VenueScraper do
  @moduledoc """
  Documentation for VenueScraper.
  """

  @doc """
  Hello world.

  ## Examples

      iex> VenueScraper.hello
      :world

  """

  # Sidewinder   - queueapp
  # Barracuda    - queueapp
  # CATIL        - HTML parsing
  # Mohawk       - HTML parsing
  # Dirty Dog    - Facebook (???)

  # Normalized record should include:
  # - presents
  # - title
  # - description
  # - doors_at
  # - starts_at
  # - bands       - array of artists if supplied
  # - venue
  #
  # TODO: research on this?
  # if need be, a primary key can be timestamp-venue_name

  @lastfm_url "https://ws.audioscrobbler.com/2.0/"
  @lastfm_api_key Application.get_env(:venue_scraper, :lastfm_api_key)

  # Elasticsearch index
  @music_path "/music"
  @events_path @music_path <> "/events"

  # Fetch bands for a given last.fm user
  def get_bands_for(user \\ "SP420") do
    url = @lastfm_url <> "?method=user.gettopartists&user=#{user}&api_key=#{@lastfm_api_key}&format=json&period=overall&limit=500"
    fetch_bands(url, 1)
  end

  def fetch_bands(url, page, artists \\ [])
  def fetch_bands(url, page, artists) do
    case HTTPoison.get(url <> "&page=#{page}") do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        new_artists = Poison.decode!(body)
        |> Map.get("topartists")
        |> Map.get("artist")
        |> Enum.map(&(&1["name"]))

        if Enum.count(new_artists) > 0 do
          fetch_bands(url, page + 1, artists ++ new_artists)
        else
          artists ++ new_artists
        end
      {:error, %HTTPoison.Error{reason: reason}} ->
        IO.inspect(reason)
    end
  end

   # Come and Take It Live
  def catil do
    # url = "https://www.ticketfly.com/venue/22421-come-and-take-it-live/"
    # HTTPoison.get!(url).body
    File.read!("./lib/20170514_catil.html")
    |> Floki.find("div.event-results ul")

    # returns ul tuple
    |> List.first

    # returns list of li elements (nodes are {tag_name, attributes, children_nodes})
    |> elem(2)
    |> Enum.map(fn(li) ->
      # TODO: Determine difference between starts_at/doors_at, need to look at next node over
      presents = Floki.find(li, "div:nth-child(2) p.event-results-sponsor") |> Floki.text
      title = Floki.find(li, "div:nth-child(2) h3") |> Floki.text

      # TODO: Move to "presents" and make it an array since this is almost always comma-separated bands
      # TODO: grab event show link from here
      description = Floki.find(li, "div:nth-child(2) p.description") |> Floki.text

      # The timezone offset can be like 3 different ones so it's crap, but the actual hours/minute/seconds seem to be
      # consistently in the correct timezone of the parser, so we discard the timezone offset
      starts_at_raw = Floki.find(li, "div.event-date span")
        |> Floki.attribute("title")
        |> Enum.at(0)
        |> (&Regex.run(~R/\d{4}-\d{2}-\d{2}T\d{1,2}:\d{2}:\d{2}/, &1)).()
        |> Enum.at(0)

      # Parse similarly to what is done for queueapp JSON
      starts_at = Timex.parse("#{starts_at_raw} #{Timex.Timezone.Local.lookup}", "{YYYY}-{0M}-{0D}T{h24}:{m}:{s} {Zname}")
        |> elem(1)
        |> Timex.format("{ISO:Extended:Z}")
        |> elem(1)

      %{
        presents: presents,
        title: title,
        description: description,
        starts_at: starts_at,
        venue: "Come and Take It Live"
      }
    end)
  end

  def mohawk do
    # url = "https://mohawkaustin.com/events"
    # HTTPoison.get!(url, [], [recv_timeout: 15000]).body
    File.read!("./lib/20180218_mohawk.html")
      |> Floki.find("section.calendar div.event-large")
      |> Enum.map(fn(div) ->
        # e.g. "Sun Feb 18"
        raw_date = Floki.find(div, ".event-bar h4") |> List.first |> elem(2) |> List.first

        # e.g. "6:30PM"
        raw_time = Floki.find(div, ".event-bar h6")
          |> List.first
          |> elem(2)
          |> List.first
          |> (&Regex.run(~R/\d{1,2}:\d{2} (AM|PM)/, &1)).()
          |> List.first
          |> (&Regex.replace(~R/\s/, &1, "")).()

        # TODO: figure out what to do when grabbing dates from the following year
        # converts e.g. "Sun Feb 1 6:30PM America/Chicago 2018" to e.g. "2018-02-02T00:30:00Z"
        doors_at = Timex.parse("#{raw_date} #{raw_time} #{Timex.Timezone.Local.lookup} #{Timex.today.year}", "%a %b %e %l:%M%p %Z %Y", :strftime)
          |> elem(1)
          |> Timex.format("{ISO:Extended:Z}")
          |> elem(1)

        IO.inspect(doors_at)
        billing_div = Floki.find(div, ".billing")

        # presents may/may not be there
        presents = Floki.find(billing_div, "h6")
          |> List.first
          |> (fn
            presents when is_nil(presents) -> nil
            presents when is_tuple(presents) -> elem(presents, 2) |> List.first
          end).()

        title = Floki.find(billing_div, "h1")
          |> List.first
          |> elem(2)
          |> List.first

        # Bands may/may not be there
        bands = Floki.find(billing_div, "h5")
          |> List.first
          |> (fn
            bands when is_nil(bands) -> nil
            bands when is_tuple(bands) -> elem(bands, 2) |> Enum.filter(fn(band) -> is_bitstring(band) && band != "More" end)
          end).()

          %{
            presents: presents,
            title: title,
            bands: bands,
            doors_at: doors_at,
            venue_name: "Mohawk"
          }
      end)
  end

  # def test do
  #   doors_at = Timex.parse("Thu Mar 1 7:00PM #{Timex.Timezone.Local.lookup} #{Timex.today.year}", "%a %b %e %l:%M%p %Z %Y", :strftime)
  #         # |> elem(1)
  #         # |> Timex.format("{ISO:Extended:Z}")
  #         # |> elem(1)
  #   IO.inspect(doors_at)
  # end

  # Covers Sidewinder and Barracuda
  def queueapp_json_for(url \\ "https://sidewinder.queueapp.com/feeds/events.json", venue_name \\ "Sidewinder") do
    keys = ~W[title presents description id starts_at doors_at performing]

    #File.read!("./lib/20170409_sidewinder.json")
    HTTPoison.get!(url).body
      |> Poison.decode!
      |> Enum.map(fn(json) ->
        # converts e.g. "2017-07-04 18:00 America/Chicago" into an ISO8601 string "2017-07-04T23:00:00Z"
        doors_at = Timex.parse("#{Map.get(json, "starts_at")} #{Map.get(json, "doors_at")} #{Timex.Timezone.Local.lookup}", "{YYYY}-{0M}-{0D} {h24}:{m} {Zname}")
          |> elem(1)
          |> Timex.format("{ISO:Extended:Z}")
          |> elem(1)

        %{
          presents: Map.get(json, "presents"),
          title: Map.get(json, "title"),
          description: Map.get(json, "description"),
          bands: Map.get(json, "performing"),
          doors_at: doors_at,
          venue: venue_name
        }
    end)
  end

  def bands_at_venue?(user_bands, venue_bands) do
    intersection = MapSet.intersection(MapSet.new(user_bands), MapSet.new(venue_bands))
    MapSet.size(intersection) > 0
  end

  # TODO: Use ES Bulk API instead of one-by-one
  # Takes an array of events and indexes them into ES
  def index_events(events) do
    Enum.each(events, fn(event) ->
      time = Map.get(event, :doors_at) || Map.get(event, :starts_at)

      # regex removes all non-words but leaves whitespace
      title = Regex.replace(~R/[^\w\s]/, Map.get(event, :title), "") |> String.split |> Enum.join("_")

      # index end result e.g. "2017-07-21T02:00:00Z_Summer_Slam_II"
      put!("#{@events_path}/#{time}_#{title}", event)
    end)
  end

  def search_events_for(text) do
    query = search([index: @events_path]) do
      query do
        bool do
          should do
            wildcard "bands", "*#{text}*"
            wildcard "title", "*#{text}*"
            wildcard "presents", "*#{text}*"
          end
        end
      end
    end

    Tirexs.Query.create_resource(query)
  end

  def empty_index do
    Tirexs.HTTP.delete(@music_path)
  end

  defp iso8601_for(date_string) do
  end

end
