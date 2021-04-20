using System.Threading.Tasks;
using Google.Cloud.BigQuery.V2;

namespace NYCTaxiTrips.Data
{
    public interface IGoogeBigQueryRepo
    {
        Task<BigQueryResults> GetData(string query);
    }
}