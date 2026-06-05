FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

COPY WebSearch.sln ./
COPY src/WebSearch.Application/WebSearch.Application.csproj src/WebSearch.Application/
COPY src/WebSearch.Api/WebSearch.Api.csproj src/WebSearch.Api/

RUN dotnet restore src/WebSearch.Api/WebSearch.Api.csproj

COPY src/WebSearch.Application/ src/WebSearch.Application/
COPY src/WebSearch.Api/ src/WebSearch.Api/

RUN dotnet publish src/WebSearch.Api/WebSearch.Api.csproj \
    -c Release \
    -o /app/publish \
    /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final
WORKDIR /app

ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080

COPY --from=build /app/publish .

ENTRYPOINT ["dotnet", "WebSearch.Api.dll"]
