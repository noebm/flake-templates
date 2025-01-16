{
  description = "My programming templates";

  outputs = {self}: {
    templates = {
      bevy = {
        description = "A bevy template, using crane";
        path = ./bevy;
      };
    };
  };
}
