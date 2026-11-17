//! The fork's name for its engine, defined once.
//!
//! It names every folder the engine keeps for itself (configuration, data,
//! state, caches, the system-wide config), the OS keyring service its secrets
//! sit under, and every name users see (`--version`, the usage line, the user
//! agent). It must equal the goose-cli `[[bin]]` name for `src/main.rs`;
//! `martha/checks` enforces that.

/// Expands to the engine's name as a string literal, so it also works inside
/// `concat!`.
#[macro_export]
macro_rules! engine_name {
    () => {
        "martha-engine"
    };
}

/// The engine's name.
pub const ENGINE_NAME: &str = engine_name!();

/// The engine's organisation, for the folder layouts that name one (the macOS
/// bundle id, Windows `AppData\<author>`).
pub const ENGINE_AUTHOR: &str = "Macula";

/// The top-level domain of the macOS bundle id.
pub const ENGINE_TOP_LEVEL_DOMAIN: &str = "io";

/// The platform folder layout for the engine, as `etcetera` takes it.
#[macro_export]
macro_rules! engine_app_strategy_args {
    () => {
        etcetera::AppStrategyArgs {
            top_level_domain: $crate::ENGINE_TOP_LEVEL_DOMAIN.to_string(),
            author: $crate::ENGINE_AUTHOR.to_string(),
            app_name: $crate::ENGINE_NAME.to_string(),
        }
    };
}
