using System;
using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace WebSearch.Application.Data.Migrations
{
    /// <inheritdoc />
    public partial class InitialRequestLogs : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "request_logs",
                columns: table => new
                {
                    id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    endpoint = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false),
                    query_or_url = table.Column<string>(type: "text", nullable: false),
                    source = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: true),
                    duration_ms = table.Column<long>(type: "bigint", nullable: false),
                    cache_hit = table.Column<bool>(type: "boolean", nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_request_logs", x => x.id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_request_logs_created_at",
                table: "request_logs",
                column: "created_at");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "request_logs");
        }
    }
}
