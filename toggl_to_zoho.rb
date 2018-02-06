class ZohoClient
  AUTH_TOKEN = ENV['ZOHO_TOKEN']
  require 'httparty'
  require 'date'
  include HTTParty
  base_uri 'http://people.zoho.eu/people/api'

  def initialize
    @query = {
      authtoken: AUTH_TOKEN,
      user: ENV['ZOHO_EMAIL']
    }
  end

  def get_job_id job_name
    @job_ids ||= Hash.new do |ids, name|
      ids[name] = 'name'
    end
    @job_ids[job_name]
  end

  def get_logs
    query = @query.merge({
      jobId: :all,
      fromDate: Date.today - 200,
      toDate: Date.today,
      billingStatus: :all
    })
    self.class.get('/timetracker/gettimelogs', query: query )
  end

  def add_time time_log
    query = @query.merge(time_log)
    self.class.get('/timetracker/addtimelog', query: query )
  end

  def get_jobs
    self.class.get('/timetracker/getjobs', query: @query)
  end
end

require 'togglv8'
require 'json'
require 'date'
require 'byebug'

toggl_api = TogglV8::API.new(ENV['TOGGL_TOKEN'])
workspace_id = toggl_api.my_workspaces.first['id']
reports = TogglV8::ReportsV2.new(api_token: ENV['TOGGL_TOKEN'])
reports.workspace_id  = workspace_id
monday = Date.today - Date.today.wday
toggl_report = reports.details('', { since: monday-7, until: monday })

def toggl_to_zoho toggl
  {
    workDate: toggl['start'][0..9],
    billingStatus: toggl['client'] ? 'Billable' : 'Non-Billable',
    jobId: '6323000000061527',
    project: toggl['project'],
    hours: Time.at(toggl['dur']/1000).utc.strftime('%H:%M'),
    fromTime: nil,
    toTime: nil,
    description: toggl['description'],
    workItem: nil
  }.compact
end

toggl_report.each do |toggl_hash|
  zoho_hash = toggl_to_zoho(toggl_hash).compact
  ZohoClient.new.add_time(zoho_hash)
end
