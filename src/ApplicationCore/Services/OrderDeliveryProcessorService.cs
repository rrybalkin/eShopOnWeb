using System;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.eShopWeb.ApplicationCore.Entities.OrderAggregate;
using Microsoft.eShopWeb.ApplicationCore.Interfaces;

public class OrderDeliverProcessorService : IOrderReservationService
{
    private readonly string orderServiceUrl = Environment.GetEnvironmentVariable("ORDER_ITEMS_DELIVERY_PROCESSOR_URL") ?? "Not set";
    private readonly string orderServiceApiKey = Environment.GetEnvironmentVariable("ORDER_ITEMS_DELIVERY_PROCESSOR_API_KEY") ?? "Not set";
    private readonly HttpClient _httpClient;

    public OrderDeliverProcessorService()
    {
        _httpClient = new HttpClient();
    }

    public async Task ReserveOrder(Order order)
    {
        try
        {
            // Convert the object to JSON
            var jsonContent = JsonSerializer.Serialize(order);

            using var content = new StringContent(jsonContent, Encoding.UTF8, "application/json");

            var fullUrl = orderServiceUrl + "?code=" + orderServiceApiKey;
            var response = await _httpClient.PostAsync(fullUrl, content);

            // Throw an exception if the request was not successful
            response.EnsureSuccessStatusCode();

            // Read the string result returned by the server
            var result = await response.Content.ReadAsStringAsync();
            Console.WriteLine("Response from the reservation order service: " + response);
        }
        catch (Exception e)
        {
            // Log or handle exceptions as required
            Console.WriteLine($"An error occurred while reserving order: {e.Message}");
        }
    }
}