using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CcDashboard.Infrastructure.Migrations.App
{
    /// <inheritdoc />
    public partial class SeparateBackendTablesToBeDb : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // NO-OP: Tables remain in database, now owned by BackendEmulationDbContext.
            // This migration only updates AppDbContext's model snapshot to exclude NGC_*/RTS_* entities.
            // ADR-007: Database boundary - shell tables vs backend tables.
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // NO-OP: Tables remain in database, owned by BackendEmulationDbContext.
            // Rollback does not need to recreate tables that were never dropped.
        }
    }
}
