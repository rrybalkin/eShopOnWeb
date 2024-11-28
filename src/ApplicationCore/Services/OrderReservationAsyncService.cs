using System;
using System.Text.Json;
using System.Threading.Tasks;
using Azure.Messaging.ServiceBus;
using Microsoft.eShopWeb.ApplicationCore.Entities.OrderAggregate;
using Microsoft.eShopWeb.ApplicationCore.Interfaces;

public class OrderReservationAsyncService : IOrderReservationService
{
    private readonly string connectionString = Environment.GetEnvironmentVariable("SERVICE_BUS_CONNECTION_STRING") ?? "Not set";
    private readonly string queueName = "eshop-orders";

    private readonly ServiceBusClient _serviceBusClient;

    public OrderReservationAsyncService()
    {
        _serviceBusClient = new ServiceBusClient(connectionString);

        Console.WriteLine("OrderReservationAsyncService initialized with queueName=" + queueName);
    }


    public async Task ReserveOrder(Order order)
    {
        ServiceBusSender _sender = _serviceBusClient.CreateSender(queueName);
        try
        {
            // Convert the object to JSON
            var jsonContent = JsonSerializer.Serialize(order);
            var orderMessage = new ServiceBusMessage(jsonContent);

            await _sender.SendMessageAsync(orderMessage);
            Console.WriteLine("The new order message successfully sent to Queue");
        }
        catch (Exception e)
        {
            // Log or handle exceptions as required
            Console.WriteLine($"An error occurred while reserving order: {e.Message}");
        }
        finally
        {
            await _sender.DisposeAsync();
        }
    }
}

