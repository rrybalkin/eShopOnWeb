using System;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.eShopWeb.ApplicationCore.Entities.OrderAggregate;
using Microsoft.eShopWeb.ApplicationCore.Interfaces;

public class OrderReservationService : IOrderReservationService
{
    // of course this could be done in better way via environment variables
    private readonly string orderServiceUrl = "https://cloudxeshopwebappv2.azurewebsites.net/api/OrderItemsReserver?code=zF7_eOqfqGOW0i5VY5d-j-GyviKE4r4s8Jlols_dx4WXAzFuMFzbxQ%3D%3D";
    private readonly HttpClient _httpClient;

    public OrderReservationService()
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

            var response = await _httpClient.PostAsync(orderServiceUrl, content);

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