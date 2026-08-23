{
  buildGleamApplication,
  erlang,
}:

buildGleamApplication {
  src = ./.;
  erlangPackage = erlang;

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    gleam test
    runHook postCheck
  '';

  meta = {
    description = "Validates the bell.plus schedule data format";
    homepage = "https://github.com/nicolaschan/schedules";
    mainProgram = "bell_validator";
  };
}
