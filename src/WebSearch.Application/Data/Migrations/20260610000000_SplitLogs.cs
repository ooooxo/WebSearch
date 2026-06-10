using System;
using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace WebSearch.Application.Data.Migrations
{
    /// <inheritdoc />
    public partial class SplitLogs : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Drop old unified log table if it exists from a prior deployment
            migrationBuilder.Sql("DROP TABLE IF EXISTS request_logs;");

            migrationBuilder.CreateTable(
                name: "search_logs",
                columns: table => new
                {
                    id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    query = table.Column<string>(type: "text", nullable: false),
                    normalized_query = table.Column<string>(type: "text", nullable: false),
                    source = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false),
                    result_count = table.Column<int>(type: "integer", nullable: false),
                    cache_hit = table.Column<bool>(type: "boolean", nullable: false),
                    duration_ms = table.Column<long>(type: "bigint", nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_search_logs", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "scrape_logs",
                columns: table => new
                {
                    id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    url = table.Column<string>(type: "text", nullable: false),
                    source = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false),
                    success = table.Column<bool>(type: "boolean", nullable: false),
                    cache_hit = table.Column<bool>(type: "boolean", nullable: false),
                    content_length = table.Column<int>(type: "integer", nullable: false),
                    duration_ms = table.Column<long>(type: "bigint", nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_scrape_logs", x => x.id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_search_logs_created_at",
                table: "search_logs",
                column: "created_at");

            migrationBuilder.CreateIndex(
                name: "IX_search_logs_source_created_at",
                table: "search_logs",
                columns: new[] { "source", "created_at" });

            migrationBuilder.CreateIndex(
                name: "IX_scrape_logs_url_created_at",
                table: "scrape_logs",
                columns: new[] { "url", "created_at" });

            migrationBuilder.CreateIndex(
                name: "IX_scrape_logs_source_created_at",
                table: "scrape_logs",
                columns: new[] { "source", "created_at" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(name: "search_logs");
            migrationBuilder.DropTable(name: "scrape_logs");
        }
    }
}
