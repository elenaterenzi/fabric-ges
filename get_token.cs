using Microsoft.Identity.Client; 
using System.Net.Http.Headers; 

#region parameters section 
string ClientId = "YourApplicationId";  
string Authority = "https://login.microsoftonline.com/organizations"; 
string RedirectURI = "http://localhost";  
#endregion 

#region Acquire a token for Fabric APIs 
// In this sample we acquire a token for Fabric service with the scopes Workspace.ReadWrite.All and Item.ReadWrite.All 
string[] scopes = new string[] { "https://api.fabric.microsoft.com/Workspace.ReadWrite.All https://api.fabric.microsoft.com/Item.ReadWrite.All" }; 

PublicClientApplicationBuilder PublicClientAppBuilder = 
        PublicClientApplicationBuilder.Create(ClientId) 
        .WithAuthority(Authority) 
        .WithRedirectUri(RedirectURI); 

IPublicClientApplication PublicClientApplication = PublicClientAppBuilder.Build(); 

AuthenticationResult result = await PublicClientApplication.AcquireTokenInteractive(scopes) 
        .ExecuteAsync() 
        .ConfigureAwait(false); 

Console.WriteLine(result.AccessToken); 
#endregion 

#region Create an HTTP client and call the Fabric APIs 
// Create client 
HttpClient client = new HttpClient(); 
client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", result.AccessToken); 
string baseUrl = "https://api.fabric.microsoft.com/v1/"; 
client.BaseAddress = new Uri(baseUrl); 

// Call list workspaces API 
HttpResponseMessage response = await client.GetAsync("workspaces"); 
string responseBody = await response.Content.ReadAsStringAsync(); 
Console.WriteLine(responseBody); 
#endregion