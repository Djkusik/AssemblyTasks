assume cs:code1

data segment

    error_msg       db "Bledny format pliku wejsciowego $"   
    curr_x          dw 0000h 
    curr_y          dw 0000h
    zoom            dw 0001h
    file_handle     dw ?

    ; Z dokumentacji internetowej    
    ; BITMAPFILEHEADER ma 14 bajtow
    bfType	        dw	?
    bfSize      	dd	?
    bfReserved1	    dw	?
    bfReserved2	    dw	?
    bfOffBits	    dd	?
    ; BITMAPINFOHEADER ma 40 bajtow
    biSize      	dd	?
    biWidth	        dd	?
    biHeight	    dd	?
    biPlanes	    dw	?
    biBitCount  	dw	?
    biCompression	dd	?
    biSizeImage	    dd	?
    biXPelsPerMeter	dd	?
    biYPelsPerMeter	dd	?
    biClrUsed	    dd	?
    biClrImportant	dd	?
    ; Paleta kolorow
    palette	        dd	256 dup (?)

data ends  

image segment

    red_buffer24    db ?
    green_buffer24  db ?
    blue_buffer24   db ?  
    pixel_array     db 0fffch dup (0)                                           ; Bufor na wczytany rzad obrazu

image ends

    


code1 segment

start:             
    ; Inicjowanie stosu
    mov sp, offset peak
    mov ax, seg peak
    mov ss, ax 

    ; Ustawienie uzywanego segmentu (data)
    mov ax, data     
    mov es, ax

    ; Odczytanie argumentu programu                                         
    mov bl, byte ptr ds:[80h]                                                   ; Zapisz dlugosc wczytanego argumentu
    mov byte ptr [bx+81h], 0                                                    ; Zastap CR po argumencie nullem

    ; Ustawienie trybu graficznego konsoli
    mov al, 13h
	mov ah, 0
	int 10h 
    
    ; Ustawienie trybu odczytu do otwarcia pliku
    mov al, 0
	mov dx, 82h                                                                 ; Otworz plik z pierwszego argumentu
	mov ah, 3dh
	int 21h  

    ; Obsluga bledu otwierania pliku
	jc err_end
    
    ; Zapisanie handlera pliku z ax do pamieci
    mov dx, seg file_handle
    mov ds, dx
    mov word ptr ds:file_handle, ax
    
    ; Zapisujemy file_handle w bx dla funkcji 3fh przerwania 21h
    mov bx, ax
    mov cx, 1078                                                                ; Wielkosc naglowka (14 + 40 + 256*4 (dd))
    mov dx, seg bfType                                                          ; Wskaznik na nasz segment z headerem
    mov ds, dx
    mov dx, offset bfType  
    mov ah, 3fh                                                                 ; Odczytanie z pliku
    int 21h

; Glowna petla
main_loop:
    ; Wczytanie palety kolorow
    call load_palette

    ; Wpisanie do cx ilosci linii (320x200 => wysokosc 200 linii)
    mov cx, 200
    mov di, cx
    push dx

; Rysowanie linii
draw_row_loop:
    ; Wczytanie linii
    call load_row

    ; Zabezpieczenie obslugiwanej linia
    push cx

    ; Przygotowanie do obslugi zoomu
    mov cx, di
    mov dx, seg zoom
    mov ds, dx
    mov dx, word ptr ds:zoom 

; Petla rysujaca i przyblizajaca
zoom_loop:
    ; Wywolaj rysowanie
    call draw_row

    dec di                                                                      ; Ile wypisano linii
    dec cx                                                                      ; W ktorej linii jestesmy
    dec dx                                                                      ; Ile razy ma sie wykonac zoom (ponowne rysowanie linii)
    cmp dx, 0
    jg zoom_loop                                                                 ; Rysuj ponownie

    ; Przywroc linie z przed wypisywania jej zoom razy i przejdz do nastepnej
    pop cx
    dec cx
    cmp di, 0
    jg draw_row_loop

    pop dx

    ; Oczekiwanie na input z klawiatury
    mov ah, 00h
    int 16h

    ; Wykonanie akcji zaleznie od wcisnietego przycisku
    cmp ah, 050h                                                                ; Strzalka w dol
    je go_down
    cmp ah, 048h                                                                ; Strzalka w gore
    je go_up
    cmp ah, 04Bh                                                                ; Strzalka w lewo
    je go_left
    cmp ah, 04Dh                                                                ; Strzalka w prawo
    je go_right
    cmp ah, 00Dh                                                                ; Znak plusa
    je zoom_up 
    cmp ah, 00Ch                                                                ; Znak minusa
    je zoom_down
    cmp ah, 01h                                                                 ; Znak escape (wyjscie)
    je the_end
    
    jmp main_loop

; Przybliz
zoom_up:
    ; Ustaw segment i offset
    mov dx, seg zoom
    mov ds, dx
    mov dx, word ptr ds:zoom
    cmp dx, 8                                                                   ; Maksymalne ograniczenie na powiekszenie
    je main_loop
    shl dx, 1                                                                   ; Przesuniecie bitowe o 1 (razy 2 powieksz)
    mov word ptr ds:zoom, dx

    ; Powroc i pokaz obrazek
    jmp main_loop

; Oddal
zoom_down:
    ; Ustaw segment i offset
    mov dx, seg zoom
    mov ds, dx
    mov dx, word ptr ds:zoom
    cmp dx, 1                                                                   ; Maksymalne ograniczenie na pomniejszenie
    je main_loop
    shr dx, 1                                                                   ; Przesuniecie bitowe o 1 (podziel 2)
    mov word ptr ds:zoom, dx

    ; Powroc i pokaz obrazek
    jmp main_loop

; Idz w dol
go_down:
    ; Ustaw segment i offset
    mov dx, seg curr_y
    mov ds, dx 
    mov dx, word ptr ds:curr_y
    add dx, 2                                                                   ; O ile pikseli przejsc
    mov word ptr ds:curr_y, dx

    ; Powroc i pokaz obrazek
    jmp main_loop

; Idz w gore
go_up:
    ; Ustaw segment i offset
    mov dx, seg curr_y
    mov ds, dx 
    mov dx, word ptr ds:curr_y
    sub dx, 2                                                                   ; O ile pikseli przejsc
    mov word ptr ds:curr_y, dx

    ; Powroc i pokaz obrazek
    jmp main_loop

; Idz w lewo
go_left:
    ; Ustaw segment i offset
    mov dx, seg curr_y
    mov ds, dx 
    mov dx, word ptr ds:curr_x
    sub dx, 2                                                                   ; O ile pikseli przejsc
    mov word ptr ds:curr_x, dx

    ; Powroc i pokaz obrazek
    jmp main_loop
    
; Idz w prawo
go_right:
    ; Ustaw segment i offset
    mov dx, seg curr_y
    mov ds, dx 
    mov dx, word ptr ds:curr_x
    add dx, 2                                                                   ; O ile pikseli przejsc
    mov word ptr ds:curr_x, dx

    ; Powroc i pokaz obrazek
    jmp main_loop
        
; Zakoncz dzialanie
the_end:
    ; Ustaw segment i offset
    mov dx, seg file_handle
    mov ds, dx

    ; Pobierz handle do pliku i go zamknij
    mov bx, word ptr ds:file_handle
    mov ah, 3eh
    int 21h

    ; Zmien tryb konsoli na tekstowy z powrotem
    mov ah, 0
    mov al, 03h
    int 10h

    ; Zakoncz program
    mov ax, 4c00h
    int 21h   

; Wypisz blad i zakoncz
err_end:
    ; Zmien tryb konsoli na tekstowy z powrotem
    mov ah, 0
    mov al, 03h
    int 10h
    
    ; Wypisz blad
    mov dx, offset error_msg 
    mov ax, seg error_msg
    mov ds, ax
    mov ah, 9
    int 21h  
    
    ; Zakoncz program
    mov ax, 4c00h
    int 21h    

; Wczytanie linii (nr linii w cx)
load_row:
    ; Zabezpiecz cx
    push cx
    dec cx                                                                      ; Zmniejsz cx ('pierwsza' linia jest dla nas zerowa)
    
    ; Ustaw obecna linie
    mov dx, seg curr_x 
    mov ds, dx
 
    ; Zabezpiecz cx
    push cx
    xor cx, cx                                                                  ; Wyzeruj cx
    
    ; Przejdz za naglowek
    mov dx, word ptr ds:bfOffBits                                               ; Pobierz offset do tablicy pikseli w pliku
    mov bx, word ptr ds:file_handle                                             ; Pobierz handler do pliku
    mov al, 0                                                                   ; SEEK FROM BEGIN => Zaczynamy od poczatku pliku
    mov ah, 42h
    int 21h

    ; Pobierz cx
    pop cx
    mov ax, cx                                                                  ; Wczytaj do ax nasze cx (numer linii do wczytania)
    push cx

    ; Sprawdzamy w ktorej linii w calym pliku jest wczytywany obraz
    mov cx, word ptr ds:biHeight                                                ; Pobieramy wysokosc calego pliku
    sub cx, ax
    mov ax, word ptr ds:curr_y                                                  ; Pobieramy obecna wspolrzedna y w pliku wyswietlanym
    sub cx, ax                                                                  ; cx = height - cx - curr_y

    ; Jesli wychodzimy poza obrazek dolem, zamaluj na czarno
    cmp cx, 0
    jl null_line

    ; Jesli wychodzimy poza obrazek gora, zamaluj na czarno
    cmp cx, word ptr ds:biHeight
    jge null_line

    ; Jesli nie wychodzimy, kontynuuj
    jmp cont_read 

; Wczytaj pozostaly obszar na czarno
null_line:
    push di
    mov di, 0
    mov al, 0;

; Petla wczytywania czarnego
black_loop:
    ; Ustaw segment image
    mov dx, seg pixel_array
    mov ds, dx
    mov byte ptr ds:pixel_array[di], al                                         ; Wpisz zero do pixel_array'u

    ; Sprawdz czy miesci sie w szerokosci
    inc di                                                                      ; Zwieksz offset
    mov dx, seg biWidth
    mov ds, dx
    cmp di, word ptr ds:biWidth                                                 ; Sprawdz czy sie miesci
    jl black_loop

    ; Przywroc rejestry
    pop di
    pop ax
    pop cx 
    ret

; Kontynuacja odczytywania
cont_read:
    ; Zapisanie w ax cx (linia), szerokosci obrazka do cx
    mov ax, cx
    mov cx, word ptr ds:biWidth

    ; Poprawka na wielkosc rzedu ktory jest wyrownany do czterech bajtow
    ; Zabezpieczenie rejestrow
    push ax
    push bx
    push dx

    mov ax, cx
    mov bx, word ptr ds:biBitCount                                              ; Liczba bitow na piksel
    mul bx 

    add ax, 31
    jnc notoveradd
    add dx, 1

notoveradd:
    mov bx, 32
    div bx

    mov bx, 4
    mul bx
    mov cx, ax

    pop dx
    pop bx
    pop ax
    ; Koniec poprawki

    ; Mnozymy ilosc rzedu * dlugosc rzedu, w celu dojscia na poczatek odpowiedniej linii
    mul cx                                                                      ; Wynik w dx:ax
    mov cx, dx
    mov dx, ax                                                                  ; Przeniesienie do cx:dx

    ; Przejscie na poczatek wybranej linii
    mov bx, word ptr ds:file_handle
    mov al, 1                                                                   ; SEEK FROM CURRENT => z poczatku na srodek
    mov ah, 42h
    int 21h                                                                     ; przejdz na poczatek szukanej linii

    ; Sprawdz czy to bmp 24bitowy
    cmp byte ptr ds:biBitCount, 24
    je read_line24                                                               ; Odczyt 24bitowe
    
    ; W przypadku 8bitowej wprost odczytaj linie bajt po bajcie
    mov cx, word ptr ds:biWidth
    mov dx, seg pixel_array
    mov ds, dx
    mov dx, offset pixel_array  
    mov ah, 3fh                                                                 ; Czytaj z pliku linie
    int 21h

    ; Przywroc rejestry
    pop ax
    pop cx 
    ret

; Odczyt linii bmp 24bitowej
read_line24:
    ; Zabezpiecz di
    push di
    mov di, 0                                                                   ; Obecny bajt w linii do przerobienia

; Przygotowanie pikseli
prepare_pixel:        

    ; Ustalenie segmentu i offsetu
    mov dx, seg red_buffer24
    mov ds, dx
    mov dx, offset red_buffer24  
    
    ; Odczytaj 3 bajty (info o jednym pikselu)
    mov cx, 3
    mov ah, 3fh
    int 21h

    ; Pobierz 3 najstarsze bity RED
    mov ax, 0
    mov ah, byte ptr ds:red_buffer24
    and ah, 11100000b                                                           ; Maska

    ; Dodanie do wynikowego al (RRR00000)
    add al, ah

    ; Pobierz 3 najstarsze bity GREEN
    mov ah, byte ptr ds:green_buffer24
    and ah, 11100000b
    mov cl, 3                                                                   ; Ustal liczbe bitow do przesuniecia bitowego
    shr ah, cl                                                                  ; Przesuniecie bitowe (by dopasowac do wynikowego)

    ; Dodanie do wynikowego al (RRRGGG00)
    add al, ah

    ; Pobierz 2 najstarsze bity BLUE
    mov ah, byte ptr ds:blue_buffer24
    and ah, 11000000b
    mov cl, 6
    shr ah, cl

    ; Dodanie do wynikowego al (RRRGGGBB)
    add al, ah

    ; Ustawienie segmentu
    mov dx, seg pixel_array
    mov ds, dx

    ; Wpisanie wyniku do pixel_array'u
    mov byte ptr ds:pixel_array[di], al 

    ; Zwieksz di (kolejny bajt)
    inc di

    ; Sprawdz czy miesci sie w szerokosci bmp
    mov dx, seg biWidth
    mov ds, dx
    cmp di, word ptr ds:biWidth
    jl prepare_pixel                                                             ; Przygotowanie kolejnych

    ; Wyczyszczenie buforow przetrzymujacych kolor, z powodu artefaktow poza ramkami obrazu
    mov dx, seg red_buffer24
    mov ds, dx
    mov byte ptr ds:red_buffer24, 00h 
    mov byte ptr ds:green_buffer24, 00h 
    mov byte ptr ds:blue_buffer24, 00h 

    ; Przywrocenie rejestrow
    pop di
    pop ax
    pop cx 
    ret

; Rysuj linie
draw_row:
    ; Zabezpiecz rejestry
    push ax
    push bx
    push cx 
    push dx

    ; Zmniejsz cx ('pierwsza' linia jest dla nas zerowa)
    dec cx

    ; Ustaw obecna wspolrzedna x wyswietlanego obrazka
    mov dx, seg curr_x
    mov ds, dx

    ; Ustalamy wskaznik na poczatek wyswietlanej linii
    mov ax, cx
    mov bx, 320
    mul bx

    ; Wpisujemy do cx ile razy rysujemy (szerokosc 320)
    mov cx, 320
    mov dx, cx
    push di

; Odczytanie zoomu i wypisanie zoom razy linii
line_loop:
    mov di, seg zoom
    mov ds, di
    mov di, word ptr ds:zoom

; Rysowanie zoom razy linii
pix_zoom_loop:
    ; Wywolaj rysowanie linii
    call set_pixel_in_line

    dec dx                                                                      ; Wyswietlana szerokosc (ile zostalo do wyswietlenia)
    dec di                                                                      ; Ile razy wypisac dany pixel
    cmp di, 0
    jg pix_zoom_loop

    loop line_loop
    pop di

    ; Przywroc rejestry
    pop dx
    pop cx
    pop bx
    pop ax

    ret

; Wysietlanie piksela na aktualnej linii (w ax mamy wspolrzedna y*320, a w cx mamy x)
set_pixel_in_line:
    ; Zabezpiecz rejestry
    push ax
    push dx
    push cx

    ; Zmniejsz cx ('pierwszy' piksel jest dla nas zerowa)
    dec cx

    ; Dodajemy cx do ax by miec offset gdzie wpisujemy w pamieci VGA
    add ax, cx
    mov cx, ax

    ; Ustalamy wskaznik na pamiec VGA
    mov dx, 0A000h                                                              ; Wskaznik na pamiec VGA
    mov es, dx                                                                  ; Ustawiamy ekstra segment na pamiec VGA

    ; Pobieramy zapisana linie pikseli
    mov dx, seg pixel_array
    mov ds, dx

    ; Wydobywamy y i x [(y*320+x) / 320 = y reszta x]
    xor dx, dx
    mov bx, 320
    div bx                                                                      ; ax = y; dx = x

    ; Do curr_x (krawedzi wyswietlanej) dodajemy obecnego x
    mov bx, dx
    mov dx, seg curr_x
    mov ds, dx
    mov dx, word ptr ds:curr_x
    add bx, dx

    ; Pobieramy zapisana linie pikseli
    mov dx, seg pixel_array
    mov ds, dx

    ; Odczytujemy z x'owej kolor ze szczytanej linii
    mov al, byte ptr ds:[bx] 

    ; Magia
    mov bx, cx                                                                  ; cx = 320*y => bx = 320*y
    pop cx                                                                      ; cx = x
    sub bx, cx                                                                  ; bx - cx
    pop dx                                                                      ; dx = ile zostalo do wyswietlenia
    add bx, dx                                                                  ; Podmienienie x do ktorego by wpisano kolor, na x do ktorego kolor wpisac chcemy (zoom case)

    ; Zapisanie do palety kolorow VGA
    mov byte ptr es:[bx], al

    ; Przywrocenie ax
    pop ax
    ret

; Ladowanie palety kolorow
load_palette:
    ; Rozpoznanie trybu zapisu bitmapy (8 czy 24 bity)
    cmp ds:biBitCount, 8 
    je load_palette8
    cmp ds:biBitCount, 24
    je load_palette24

    ; W przypadku bledu
    jmp err_end

; Wczytanie palety 8bitowej
load_palette8:
    ; Zabezpieczenie rejestrow
    push ax
    push bx
    push cx 
    push dx

    ; Wyczyszczenie palety w pamieci karty VGA
    mov dx, 3C8h
    mov al, 0
    out dx, al

    ; Ustawienie segmentu z data
    mov dx, seg palette
    mov ds, dx
    mov cx, 256                                                                 ; Ustawienie ilosci bitow kolorow (ile obrotowe petli)
    mov di, offset ds:palette

; Petla ladowania 8bitowa  
load_loop8:
    ; Zabezpieczenie cx (ilosci obrotow)
    push cx

    ; Ustawienie wielkosci przesuniecia bitowego (musi byc w cl)
    mov cl, 02h

    ; RGB czytamy od tylu GRB, stad +2 przy RED, +1 przy GREEN itd.
    ; Przesuniecie i odczytanie RED
    mov al, byte ptr ds:[di+2]
    shr al, cl                                                                  ; Przesuniecie bitowe (karta miesci max 6 bitow)
    mov dx, 3C9h                                                                ; Ustawienie portu IO do palety VGA
    out dx, al                                                                  ; Rejestrowe wpisywanie do portu

    ; Przesuniecie i odczytanie GREEN
    mov al, byte ptr ds:[di+1]
    shr al, cl
    mov dx, 3C9h
    out dx, al

    ; Przesuniecie i odczytanie BLUE
    mov al, byte ptr ds:[di]
    shr al, cl
    mov dx, 3C9h
    out dx, al

    ; Przywrocenie cx
    pop cx

    ; Skok o 4 bajty (gdyz w BMP paleta jest wyrownana do czterech bajtow)
    add di, 4
    loop load_loop8                                                              ; loop dziala jak dec cx & jump addr

    ; Przywrocenie rejestrow
    pop  dx
    pop  cx 
    pop  bx
    pop  ax
    ret

; Wczytanie palety 28bitowej w konwencji RRRGGGBB
load_palette24:                                                                 ; Najmniej widoczny przez oko ludzkie jest BLUE (stad najmniejsza waznosc)
    ; Zabezpieczenie rejestrow
    push ax
    push bx
    push cx 
    push dx

    ; Wyczyszczenie palety w pamieci karty VGA
    mov dx, 3C8h
    mov al, 0
    out dx, al

    ; Zerowanie cx (chcemy wpisywac po kolei wszystkie kombinacje)
    mov cx, 0000h

; Petla ladowania 24bitowa
load_loop24:
    ; Rzutowanie BLUE
    mov al, cl
    and al, 00000011b                                                           ; Wydobadz dwa najmlodsze bity 
    mov dh, 4                                                                   ; Ustawienie 4 w dh pod exchange
    xchg dh, cl                                                                 ; Zamiana dh z cl
    shl al, cl                                                                  ; Przesuniecie bitowe (karta miesci max 6 bitow)
    xchg dh, cl                                                                 ; Powrot wartosci cl, trzymanej w dh

    ; Ustawienie portu IO do palety VGA i wpisanie
    mov dx, 3C9h
    out dx, al

    ; Rzutowanie GREEN
    mov al, cl
    and al, 00011100b                                                           ; wydobadz trzy kolejne bity 
    mov dh, 01h
    xchg dh, cl
    shl al, cl
    xchg dh, cl

    ; Ustawienie portu IO do palety VGA i wpisanie
    mov dx, 3C9h
    out dx, al

    ; Rzutowanie RED
    mov al, cl
    and al, 11100000b                                                           ; wydobadz trzy najstarsze bity
    mov dh, 02h
    xchg dh, cl
    shr al, cl
    xchg dh, cl

    ; Ustawienie portu IO do palety VGA i wpisanie
    mov dx, 3C9h
    out dx, al

    ; Zwieksz cx (do czasu uzyskania 255)
    inc cx
    cmp cx, 00ffh
    jle load_loop24

    ; Przywrocenie rejestrow
    pop  dx
    pop  cx 
    pop  bx
    pop  ax
    ret

code1 ends

stack1 segment stack
            dw  128 dup(0)
    peak    db  ?

stack1 ends

end start
