using System.IO;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.FileProviders;
using Microsoft.OpenApi.Models;
using NYCTaxiTrips.Data;
using NYCTaxiTrips.Helpers;

namespace NYCTaxiTrips
{
    public class Startup
    {
        public Startup(IConfiguration configuration)
        {
            Configuration = configuration;
        }

        public IConfiguration Configuration { get; }

        public void ConfigureServices(IServiceCollection services)
        {
            services.AddCors(options => {
                options.AddPolicy("AllowOrigin",builder => {
                    builder.AllowAnyOrigin()
                           .AllowAnyHeader()
                           .AllowAnyMethod(); 
                });
            });
            services.AddControllers();

            services.Configure<AuthenticationSettings>(Configuration.GetSection("AuthenticationSettings"));
            services.Configure<GoogleServiceSettings>(Configuration.GetSection("GoogleServiceSettings"));
            services.Configure<TaxiTripsCServiceSettings>(Configuration.GetSection("TaxiTripsServiceSettings"));

            services.AddScoped<IUserService, MockUserService>();
            services.AddScoped<IGoogeBigQueryRepo, GoogleBigQueryRepo>();
            services.AddScoped<INYCTaxiTripsRepo, BigQueryNYCTaxiTripsRepo>();
            services.AddSwaggerGen(c =>
            {
                c.SwaggerDoc("v1", new OpenApiInfo { Title = "NYCTaxiTrips", Version = "v1" });
            });
            
        }

        public void Configure(IApplicationBuilder app, IWebHostEnvironment env)
        {
            
            if (env.IsDevelopment())
            {
                app.UseDeveloperExceptionPage();
                app.UseSwagger();
                app.UseSwaggerUI(c => c.SwaggerEndpoint("/swagger/v1/swagger.json", "NYCTaxiTrips v1"));
            }
            
            app.UseRouting();

            app.UseCors("AllowOrigin");

            app.UseFileServer(new FileServerOptions{
                FileProvider = new PhysicalFileProvider(
                    Path.Combine(Directory.GetCurrentDirectory(), "Credentials")), 
                    RequestPath = "",
                    EnableDefaultFiles = true
            });

            app.UseHttpsRedirection();

            app.UseMiddleware<JwtMiddleware>();

            app.UseEndpoints(endpoints =>
            {
                endpoints.MapControllers();
            });

            
        }
    }
}
