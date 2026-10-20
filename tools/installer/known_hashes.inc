const
  EXP_BOOK = 'c9d37ad104f6c668037af4eb75238a8d54395a57c15e6de68c883b518fa30f0c';
  EXP_FONT = 'a88867207aacaa772a2f36d60ba576671cd21a7e965fb19ad6f7429818690e08';

function IsKnownBook(const H: String): Boolean;
begin
  Result := False;
  if H = '3eba8894429ac5ffb35e750ae1edba59192e131724c005c128e5700bdcb66754' then Result := True;
  if H = '5dd31cf1c282daa72e4103eb3696304e25d805d632afd89ffce1bf879e77b9ae' then Result := True;
  if H = '9a74253db94b115dc8b4dd093ec5ab88a8bf209b7dbdc8f018e2608fe2ff09d4' then Result := True;
  if H = 'c60a703e3acd9061349751ce9eb154e07d9f4ac0bc983afcf64183a44668b5bb' then Result := True;
  if H = 'c9d37ad104f6c668037af4eb75238a8d54395a57c15e6de68c883b518fa30f0c' then Result := True;
  if H = 'cb177f4f59131d461b1881a6fa7d566e38dd0de7c5a7cd2be9bb062b2948eac4' then Result := True;
end;

function IsKnownFont(const H: String): Boolean;
begin
  Result := False;
  if H = '0ba43fe00cb36458a2267e3cf1136895c070695364c7850bc1e600c319b6e5c1' then Result := True;
  if H = 'a88867207aacaa772a2f36d60ba576671cd21a7e965fb19ad6f7429818690e08' then Result := True;
end;

{ 0 yok, 1 güncel sürüm, 2 eski sürüm (Standart ya da eski Tam altyazı) }
function BookModeOf(const H: String): Integer;
begin
  Result := 0;
  if H = '3eba8894429ac5ffb35e750ae1edba59192e131724c005c128e5700bdcb66754' then Result := 2;
  if H = '5dd31cf1c282daa72e4103eb3696304e25d805d632afd89ffce1bf879e77b9ae' then Result := 2;
  if H = '9a74253db94b115dc8b4dd093ec5ab88a8bf209b7dbdc8f018e2608fe2ff09d4' then Result := 2;
  if H = 'c60a703e3acd9061349751ce9eb154e07d9f4ac0bc983afcf64183a44668b5bb' then Result := 2;
  if H = 'cb177f4f59131d461b1881a6fa7d566e38dd0de7c5a7cd2be9bb062b2948eac4' then Result := 2;
  if H = 'c9d37ad104f6c668037af4eb75238a8d54395a57c15e6de68c883b518fa30f0c' then Result := 1;
end;

