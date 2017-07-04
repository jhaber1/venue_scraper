import Tirexs.HTTP
import UUID

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
  # Grizzly Hall - HTML parsing
  # Dirty Dog    - Facebook (???)

  # Normalized record should include:
  # - presents
  # - title
  # - description
  # - doors_at
  # - starts_at
  # - bands       - array of artists if supplied

  @lastfm_url "https://ws.audioscrobbler.com/2.0/"
  @lastfm_api_key Application.get_env(:venue_scraper, :lastfm_api_key)

  @index "/music"
  @index_path @index <> "/events"

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

  # def sidewinder do
  #   # TODO
  #   # url = "https://sidewinder.queueapp.com/feeds/events.json"
  #   # HTTPoison.get!(url).body

  #   File.read!("./lib/20170409_sidewinder.json")
  #   |> Poison.decode!
  #   #|> Enum.map(&(Map.take(&1, keys)))
  # end

   # Come and Take It Live
  def catil do
    # url = "http://www.ticketfly.com/venue/22421-come-and-take-it-live/"
    # HTTPoison.get!(url).body

    File.read!("./lib/20170514_catil.html")
    |> Floki.find("div.event-results ul")

    # returns ul tuple
    |> List.first

    # returns list of li elements (nodes are {tag_name, attributes, children_nodes})
    |> elem(2)

    |> Enum.map(fn(li) ->
      # TODO: Determined difference between starts_at/doors_at, need to look at next node over
      presents = Floki.find(li, "div:nth-child(2) p.event-results-sponsor") |> Floki.text
      title = Floki.find(li, "div:nth-child(2) h3") |> Floki.text

      # TODO: grab event show link from here
      description = Floki.find(li, "div:nth-child(2) p.description") |> Floki.text

      # TODO: may/may not have timezone attached (if not, probably safe to assume time is correct, and zone is not)
      starts_at = Floki.find(li, "div.event-date span") |> Floki.attribute("title") |> Enum.at(0)

      %{
        presents: presents,
        title: title,
        description: description,
        starts_at: starts_at,
        doors_at: starts_at
      }
    end)
  end

  # Covers Sidewinder and Barracuda
  def queueapp_json_for(url \\ "https://sidewinder.queueapp.com/feeds/events.json") do
    keys = ~W[title presents description id starts_at doors_at performing]

    File.read!("./lib/20170409_sidewinder.json")
    # HTTPoison.get!(url).body
    |> Poison.decode!
    |> Enum.map(fn(json) ->
      doors_at = Timex.parse("#{Map.get(json, "starts_at")} #{Map.get(json, "doors_at")} #{Timex.Timezone.Local.lookup}", "{YYYY}-{0M}-{0D} {h24}:{m} {Zname}")
        |> elem(1)
        |> Timex.format("{ISO:Extended:Z}")
        |> elem(1)

      %{
        presents: Map.get(json, "presents"),
        title: Map.get(json, "title"),
        description: Map.get(json, "description"),
        bands: Map.get(json, "performing"),
        doors_at: doors_at
      }
    end)
  end

  def bands_at_venue?(user_bands, venue_bands) do
    intersection = MapSet.intersection(MapSet.new(user_bands), MapSet.new(venue_bands))
    MapSet.size(intersection) > 0
  end

  def index_events do

    sidewinder
    #|> put(path <> )
  end

  def empty_index do
    Tirexs.HTTP.delete(@index)
  end

end
