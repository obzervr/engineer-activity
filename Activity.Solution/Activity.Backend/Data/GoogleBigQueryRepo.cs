using System.IO;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Options;
using System.Threading.Tasks;
using Google.Cloud.BigQuery.V2;
using Google.Apis.Auth.OAuth2;

namespace NYCTaxiTrips.Data
{
    public class GoogleBigQueryRepo : IGoogeBigQueryRepo
    {
        private readonly string _projectId;
        private GoogleCredential _gcpCredential;
        private readonly string _tableName;

        public GoogleBigQueryRepo(IWebHostEnvironment hostingEnvironment, IOptions<GoogleServiceSettings> settings)
        {
            _projectId = settings.Value.ProjectId;
            var config = Path.Combine(hostingEnvironment.WebRootPath, settings.Value.CredentialFile);
            using(var jsonStream = new FileStream(config, FileMode.Open,FileAccess.Read,FileShare.Read))
                _gcpCredential = GoogleCredential.FromStream(jsonStream);
            _tableName = settings.Value.QueryTable;
        }

        public async Task<BigQueryResults> GetData(string query)
        {
            var client = BigQueryClient.Create(_projectId, _gcpCredential);
            var table = client.GetTable("bigquery-public-data","new_york" ,_tableName);
            query = query.Replace("[FULL_TABLE_NAME]", table.ToString());
            var job = client.CreateQueryJob(sql:query, 
                                            parameters:null, 
                                            options: new QueryOptions{ UseQueryCache = false});
            var data = await job.GetQueryResultsAsync();
            return data;
        }
    }
}