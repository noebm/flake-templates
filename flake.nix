{
  description = "My programming templates";

  outputs = {self}: {
    templates = {
      rust-bevy = {
        description = "A bevy template, using crane";
        path = ./rust/bevy;
      };
    };
  };
}
