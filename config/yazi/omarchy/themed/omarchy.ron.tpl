#![enable(implicit_some)]
#![enable(unwrap_newtypes)]
#![enable(unwrap_variant_newtypes)]
(
    default_album_art_path: None,
    format_tag_separator: " | ",
    multiple_tag_resolution_strategy: All,
    browser_column_widths: [20, 38, 42],
    background_color: None,
    modal_backdrop: true,
    text_color: Some("{{ accent }}"),
    header_background_color: None,
    modal_background_color: None,
    preview_label_style: (fg: "{{ foreground }}"),
    preview_metadata_group_style: (fg: "{{ muted }}", modifiers: "Bold"),
    song_table_album_separator: None,
    show_song_table_header: true,
    tab_bar: (
        active_style: (fg: "{{ foreground }}", bg: "{{ accent }}", modifiers: "Bold"),
        inactive_style: (fg: "{{ accent }}"),
    ),
    highlighted_item_style: (fg: "{{ accent }}", modifiers: "Bold"),
    current_item_style: (fg: "{{ accent }}", bg: "{{ dark_background }}", modifiers: "Bold"),
    borders_style: (fg: "{{ accent }}", modifiers: "Bold"),
    highlight_border_style: (fg: "{{ accent }}"),
    symbols: (song: "󰝚 ", dir: "󱍙 ", playlist: "󰲸 ", marker: "* ", ellipsis: "...",
        song_style: (fg: "{{ foreground }}"), song_highlighted_style: None, song_current_style: (fg: "{{ foreground }}"),
        dir_style: (fg: "{{ foreground }}"), dir_highlighted_style: None, dir_current_style: (fg: "{{ foreground }}"),
        playlist_style: (fg: "{{ foreground }}"), playlist_highlighted_style: None, playlist_current_style: (fg: "{{ foreground }}"),
        marker_style: (fg: "{{ muted }}"), marker_highlighted_style: (fg: "{{ muted }}"), marker_current_style: (fg: "{{ foreground }}"),
    ),
    progress_bar: (
        symbols: ["=", "=", "=", "=", "=" ],
        track_style: (fg: "{{ foreground }}"),
        elapsed_style: (fg: "{{ accent }}"),
        thumb_style: (fg: "{{ accent }}"),
        use_track_when_empty: false,
    ),
    scrollbar: (
        symbols: ["┋", "█", "󰄿", "󰄼"],
        track_style: (fg: "{{ foreground }}"),
        ends_style: (fg: "{{ foreground }}"),
        thumb_style: (fg: "{{ foreground }}"),
    ),
    song_table_format: [
        (
            prop: (kind: Group([
                (kind: Text(" ")),
                (kind: Property(Title), style: (fg: "{{ foreground }}"),
                    default: (kind: Property(Filename), style: (fg: "{{ foreground }}"),
                        default: (kind: Text("Unknown Title"), style: (fg: "{{ accent }}")))),
            ])),
            width: "92%",
            label_prop: (kind: Group([
                (kind: Text("Title "), style: (modifiers: "Bold")),
                (kind: Text(""), style: (fg: "{{ accent }}"))
            ]))
        ),
        (
            prop: (kind: Property(Duration), style: (fg: "{{ foreground }}"),
                default: (kind: Text("-"))),
            width: "8%",
            alignment: Right,
            label_prop: (kind: Group([
                (kind: Text("Length "), style: (modifiers: "Bold")),
                (kind: Text(" "), style: (fg: "{{ accent }}"))
            ]))
        ),
    ],
        layout: Split(
        direction: Vertical, panes: [
            (size: "7", borders: "NONE", pane: Component("header")),
            (size: "100%", borders: "NONE", pane: Pane(TabContent)),
            (size: "3", borders: "NONE", pane: Component("progress_bar")),
        ]),
    browser_song_format: [
        (kind: Group([
                    (kind: Property(Track)),
                    (kind: Text(" ")),
                ])),
        (kind: Group([
                    (kind: Property(Artist)),
                    (kind: Text(" - ")),
                    (kind: Property(Title)),
                ]), default: (kind: Property(Filename)))
    ],
    level_styles: (
        info:  (),
        warn:  (),
        error: (),
        debug: (),
        trace: (),
    ),
    components: {
        "header_tab_bar": Split(direction: Horizontal, panes: [
                    (size: "11%", borders: "NONE", pane: Component("tab_bar_left")),
                    (size: "78%", borders: "NONE", pane: Pane(Tabs)),
                    (size: "11%", borders: "NONE", pane: Component("tab_bar_right")),
            ]),
        "header_line_1": Split(direction: Horizontal, panes: [
                            (size: "22%", pane: Component("header_element_1")),
                            (size: "1", pane: Component("header_element_space")),
                            (size: "56%", pane: Component("header_element_2")),
                            (size: "1", pane: Component("header_element_space")),
                            (size: "22%", pane: Component("header_element_3")),
                            (size: "2", pane: Component("header_element_right_end")),
            ]),
        "header_line_2": Split(direction: Horizontal, panes: [
                            (size: "22%", pane: Component("header_element_4")),
                            (size: "1", pane: Component("header_element_space")),
                            (size: "56%", pane: Component("header_element_5")),
                            (size: "1", pane: Component("header_element_space")),
                            (size: "22%", pane: Component("header_element_6")),
                            (size: "2", pane: Component("header_element_right_end")),
            ]),
        "header_line_3": Split(direction: Horizontal, panes: [
                            (size: "25%", pane: Component("header_element_7")),
                            (size: "1", pane: Component("header_element_space")),
                            (size: "50%", pane: Component("header_element_8")),
                            (size: "1", pane: Component("header_element_space")),
                            (size: "25%", pane: Component("header_element_9")),
                            (size: "2", pane: Component("header_element_right_end")),

            ]),
        "header": Split(
            direction: Vertical, panes: [
                (size: "2", borders: "TOP | RIGHT | LEFT", border_symbols: Rounded,
                    pane: Split(direction: Horizontal, panes: [
                        (size: "100%", borders: "NONE", pane: Component("header_tab_bar")),
                  ])
                ),
                (size: "5", borders: "ALL", border_symbols: Library("rounded_collapsed_top"),
                  border_title: [
                            (kind: Text("─"), style: (fg: "{{ accent }}")),
                        (kind: Transform(Replace(content: (kind: Sticker("rating")), replacements: [
                            (match:  "1", replace: (kind: Group([(kind: Text("["), style: (fg: "{{ accent }}")), (kind: Text(" "),         style: (fg: "{{ accent }}")), (kind: Text("    ")), (kind: Text("]"), style: (fg: "{{ accent }}"))]))),
                            (match:  "2", replace: (kind: Group([(kind: Text("["), style: (fg: "{{ accent }}")), (kind: Text(" "),         style: (fg: "{{ accent }}")), (kind: Text("    ")), (kind: Text("]"), style: (fg: "{{ accent }}"))]))),
                            (match:  "3", replace: (kind: Group([(kind: Text("["), style: (fg: "{{ accent }}")), (kind: Text("  "),       style: (fg: "{{ accent }}")), (kind: Text("   ")), (kind: Text("]"), style: (fg: "{{ accent }}"))]))),
                            (match:  "4", replace: (kind: Group([(kind: Text("["), style: (fg: "{{ accent }}")), (kind: Text("  "),       style: (fg: "{{ accent }}")), (kind: Text("   ")), (kind: Text("]"), style: (fg: "{{ accent }}"))]))),
                            (match:  "5", replace: (kind: Group([(kind: Text("["), style: (fg: "{{ accent }}")), (kind: Text("   "),     style: (fg: "{{ accent }}")), (kind: Text("  ")), (kind: Text("]"), style: (fg: "{{ accent }}"))]))),
                            (match:  "6", replace: (kind: Group([(kind: Text("["), style: (fg: "{{ accent }}")), (kind: Text("   "),     style: (fg: "{{ accent }}")), (kind: Text("  ")), (kind: Text("]"), style: (fg: "{{ accent }}"))]))),
                            (match:  "7", replace: (kind: Group([(kind: Text("["), style: (fg: "{{ accent }}")), (kind: Text("    "),   style: (fg: "{{ accent }}")), (kind: Text(" ")), (kind: Text("]"), style: (fg: "{{ accent }}"))]))),
                            (match:  "8", replace: (kind: Group([(kind: Text("["), style: (fg: "{{ accent }}")), (kind: Text("    "),   style: (fg: "{{ accent }}")), (kind: Text(" ")), (kind: Text("]"), style: (fg: "{{ accent }}"))]))),
                            (match:  "9", replace: (kind: Group([(kind: Text("["), style: (fg: "{{ accent }}")), (kind: Text("     "), style: (fg: "{{ accent }}")), (kind: Text("]"), style: (fg: "{{ accent }}"))]))),
                            (match: "10", replace: (kind: Group([(kind: Text("["), style: (fg: "{{ accent }}")), (kind: Text("     "), style: (fg: "{{ accent }}")), (kind: Text("]"), style: (fg: "{{ accent }}"))]))),
                        ])), default: (kind: Text("─"),style: (fg: "{{ accent }}"))),
                            (kind: Text("─"), style: (fg: "{{ accent }}")),
                  ],
                  border_title_position: Bottom,
                  border_title_alignment: Right,
                  pane: Split(direction: Vertical, panes: [
                     (size: "100%", borders: "NONE", pane: Component("header_line_1")),
                     (size: "100%", borders: "NONE", pane: Component("header_line_2")),
                     (size: "100%", borders: "NONE", pane: Component("header_line_3")),
                  ])
                ),
            ]
        ),
        "progress_bar": Split(
            direction: Vertical, panes: [
              (size: "3", borders: "ALL", border_symbols: Rounded ,
                  border_title: [
                         (kind: Property(Status(Elapsed)),style: (fg: "{{ accent }}")),
                         (kind: Property(Status(StateV2(playing_label: "─󱦟─", paused_label: "  ", stopped_label: "  "))),
                             style: (modifiers: "Bold")),
                         (kind: Property(Status(Duration)),style: (fg: "{{ accent }}")),
                      ],
                  border_title_position: Top,
                  border_title_alignment: Center,
                  pane: Split(direction: Vertical, panes: [
                      (size: "100%", borders: "NONE",pane: Pane(ProgressBar)),
                ])
              ),
            ]
        ),
        "tab_bar_left": Split(direction: Horizontal, panes: [
             (size: "100%", pane: Pane(Property(content: [
                             (kind: Text(" "), style: (modifiers: "Bold")),
                             (kind: Property(Status(StateV2(playing_label: "", paused_label: "", stopped_label: ""))),
                                 style: (fg: "{{ accent }}")),
                             (kind: Text("  "), style: (modifiers: "Bold")),
                             (kind: Property(Song(FileExtension)), style: (fg: "{{ accent }}")),
                             (kind: Text(" ")),
                             (kind: Property(Widget(ScanStatus)), style: (modifiers: "Bold")),
                             (kind: Text(" ")),
                             (kind: Property(Status(InputBuffer())), style: (fg: "{{ accent }}")),
                         ], align: Left))
             ),
            ]),
        "tab_bar_right": Split(direction: Horizontal, panes: [
                 (size: "100%", pane: Pane(Property(content: [
                                 (kind: Transform(Replace(content: (kind: Property(Status(Partition)), style: (fg: "{{ accent }}")), replacements: [
                                     (match:  "default", replace: (kind: Group([(kind: Text(""))]))),
                                   ]))),
                                 (kind: Text(" ")),
                                 (kind: Text(" 󱡬"), style: (modifiers: "Bold")),
                                 (kind: Property(Status(Volume)), style: (fg: "{{ accent }}")),
                                 (kind: Text("% "), style: (modifiers: "Bold"))
                             ], align: Right))
                 ),
            ]),
        "header_element_1": Split(
            direction: Horizontal,
            panes: [
               (size: "100%", pane: Pane(Property(content: [
                               (kind: Text("[ "),style: (modifiers: "Bold")),
                               (kind: Property(Status(Elapsed)),style: (fg: "{{ accent }}")),
                               (kind: Text(" / "),style: (modifiers: "Bold")),
                               (kind: Property(Status(Duration)),style: (fg: "{{ accent }}")),
                               (kind: Text(" 󱦟"),style: (modifiers: "Bold")),
                               (kind: Text(" ]"),style: (modifiers: "Bold")),
                           ], align: Left))
               ),
            ]
        ),
        "header_element_2": Split(
            direction: Horizontal,
            panes: [
                (size: "100%", pane: Pane(Property(content: [
                                (kind: Property(Song(Title)), style: (modifiers: "Bold"),
                                    default: (kind: Property(Song(Filename)), style: (modifiers: "Bold"),
                                        default: (kind: Text("Unknown Title"), style: (modifiers: "Bold"))))
                            ], align: Center, scroll_speed: 6))
                ),
            ]
        ),
        "header_element_3": Split(
            direction: Horizontal,
            panes: [
               (size: "100%", pane: Pane(Property(content: [
                         (kind: Text("[ "),style: (modifiers: "Bold")),
                         (kind: Property(Status(RepeatV2(on_label: "", off_label: "",
                                         on_style: (modifiers: "Bold"),
                                         off_style: (modifiers: "Bold"))))),
                         (kind: Text(" | "),style: (modifiers: "Bold")),
                         (kind: Property(Status(RandomV2(on_label: "", off_label: "",
                                         on_style: (modifiers: "Bold"),
                                         off_style: (modifiers: "Bold"))))),
                         (kind: Text(" | "),style: (modifiers: "Bold")),
                         (kind: Property(Status(ConsumeV2(on_label: "󰮯", off_label: "󰮯", oneshot_label: "󰮯󰇊",
                                         on_style: (modifiers: "Bold"),
                                         off_style: (modifiers: "Bold"))))),
                         (kind: Text(" | "),style: (modifiers: "Bold")),
                         (kind: Property(Status(SingleV2(on_label: "󰎤", off_label: "󰎦", oneshot_label: "󰇊", off_oneshot_label: "󱅊",
                                         on_style: (modifiers: "Bold"),
                                         off_style: (modifiers: "Bold"))))),
                         (kind: Text(" | "),style: (modifiers: "Bold")),
                         (kind: Property(Status(Crossfade)),style: (fg: "{{ accent }}"),
                          default: (kind: Text("󰴽"), style: (fg: "{{ accent }}"))),
                         (kind: Text(" | "),style: (modifiers: "Bold")),
                         (kind: Transform(Replace(content: (kind: Property(Status(InputMode()))), replacements: [
                                 (match:  "Normal", replace: (kind: Group([(kind: Text("N"),style: (modifiers: "Bold"))]))),
                                 (match:  "Insert", replace: (kind: Group([(kind: Text("I"),style: (modifiers: "Bold"))]))),
                             ]))),
                     ], align: Right))
               ),
            ]
        ),
        "header_element_4": Split(
            direction: Horizontal,
            panes: [
                (size: "100%", pane: Pane(Property(content: [
                                (kind: Text("[ "),style: (modifiers: "Bold")),
                                (kind: Property(Song(Bits())),default: (kind: Text(" "), style: (fg: "{{ accent }}")), style: (fg: "{{ accent }}")),
                                (kind: Text(" bit"),style: (fg: "{{ accent }}")),
                                (kind: Text(" | "),style: (modifiers: "Bold")),
                                (kind: Property(Status(Bitrate)),default: (kind: Text(" "), style: (fg: "{{ accent }}")),style: (fg: "{{ accent }}")),
                                (kind: Text(" kbps"),style: (fg: "{{ accent }}")),
                                (kind: Text(" ]"),style: (modifiers: "Bold"))
                            ], align: Left))
                ),
            ]
        ),
        "header_element_5": Split(
            direction: Horizontal,
            panes: [
                 (size: "100%", pane: Pane(Property(content: [
                                 (kind: Transform(Replace(content:
                                     (kind: Property(Song(Artist)), style: (fg: "{{ accent }}"),
                                         default: (kind: Text("Unknown Artist"), style: (fg: "{{ accent }}"))),
                                   replacements: [
                                     (match:  "", replace: (kind: Group([(kind: Text("Unknown Artist"), style: (fg: "{{ accent }}"))]))),
                                   ]))),
                                 (kind: Text(" - "), style: (fg: "{{ accent }}")),
                                 (kind: Transform(Replace(content:
                                    (kind: Property(Song(Album)),style: (fg: "{{ accent }}"),
                                        default: (kind: Text("Unknown Album"), style: (fg: "{{ accent }}"))),
                                   replacements: [
                                     (match:  "", replace: (kind: Group([(kind: Text("Unknown Album"), style: (fg: "{{ accent }}"))]))),
                                   ]))),
                             ], align: Center, scroll_speed: 6))
                 ),
            ]
        ),
        "header_element_6": Split(
            direction: Horizontal,
            panes: [
                 (size: "100%", pane: Pane(Property(content: [
                                 (kind: Text("[ "),style: (modifiers: "Bold")),
                                 (kind: Property(Status(QueueTimeRemaining(separator: " "))),style: (fg: "{{ accent }}")),
                                 (kind: Text(" / "),style: (modifiers: "Bold")),
                                 (kind: Property(Status(QueueTimeTotal(separator: " "))),style: (fg: "{{ accent }}")),
                                 (kind: Text(" 󱎫"),style: (modifiers: "Bold")),
                             ], align: Right))
                 ),
            ]
        ),
        "header_element_7": Split(
            direction: Horizontal,
            panes: [
                  (size: "100%", pane: Pane(Property(content: [
                                  (kind: Text("[ "),style: (modifiers: "Bold")),
                                  (kind: Property(Song(SampleRate())),default: (kind: Text(" "), style: (fg: "{{ accent }}")), style: (fg: "{{ accent }}")),
                                  (kind: Text(" Hz"),style: (fg: "{{ accent }}")),
                                  (kind: Text(" | "),style: (modifiers: "Bold")),
                                  (kind: Property(Song(Position)), style: (fg: "{{ accent }}"),
                                      default: (kind: Text("0"), style: (fg: "{{ accent }}"))),
                                  (kind: Text(" / "),style: (modifiers: "Bold")),
                                  (kind: Property(Status(QueueLength())),style: (fg: "{{ accent }}")),
                                  (kind: Text(" 󰴍"),style: (modifiers: "Bold")),
                                  (kind: Text(" ]"),style: (modifiers: "Bold"))
                              ], align: Left))
                  ),
            ]
        ),
        "header_element_8": Split(
            direction: Horizontal,
            panes: [
               (size: "100%", pane: Pane(Property(content: [
                               (kind: Text("")),
                           ], align: Center))
               ),
            ]
        ),

        "header_element_9": Split(
            direction: Horizontal,
            panes: [
                   (size: "100%", pane: Pane(Property(content: [
                                   (kind: Text("[ "),style: (modifiers: "Bold")),
                                   (kind: Transform(Replace(content:
                                       (kind: Property(Song(Other("date"))),style: (fg: "{{ accent }}"),
                                           default: (kind: Text("Unknown Date"), style: (fg: "{{ accent }}"))),
                                   replacements: [
                                     (match:  "", replace: (kind: Group([(kind: Text("Unknown Date"), style: (fg: "{{ accent }}"))]))),
                                   ]))),
                                   (kind: Text(" | "),style: (modifiers: "Bold")),
                                   (kind: Transform(Replace(content:
                                       (kind: Property(Song(Track)),style: (fg: "{{ accent }}"),
                                           default: (kind: Text("0"), style: (fg: "{{ accent }}"))),
                                   replacements: [
                                     (match:  "", replace: (kind: Group([(kind: Text("0"), style: (fg: "{{ accent }}"))]))),
                                   ]))),
                                   (kind: Text(" / "),style: (modifiers: "Bold")),
                                   (kind: Transform(Replace(content:
                                       (kind: Property(Song(Disc)),style: (fg: "{{ accent }}"),
                                           default: (kind: Text("0"), style: (fg: "{{ accent }}"))),
                                   replacements: [
                                     (match:  "", replace: (kind: Group([(kind: Text("0"), style: (fg: "{{ accent }}"))]))),
                                   ]))),
                                   (kind: Text(" 󰥠 | "),style: (modifiers: "Bold")),
                                   (kind: Transform(Replace(content:
                                       (kind: Property(Song(Other("genre"))),style: (fg: "{{ accent }}"),
                                           default: (kind: Text("Unknown Genre"), style: (fg: "{{ accent }}"))),
                                   replacements: [
                                     (match:  "", replace: (kind: Group([(kind: Text("Unknown Genre"), style: (fg: "{{ accent }}"))]))),
                                   ]))),
                               ], align: Right))
                   ),
            ]
        ),
        "header_element_right_end": Split(
            direction: Horizontal,
            panes: [
               (size: "100%", pane: Pane(Property(content: [
                               (kind: Text(" ]"),style: (modifiers: "Bold")),
                           ], align: Right))
               ),
            ]
        ),
        "header_element_space": Split(
            direction: Horizontal,
            panes: [
               (size: "100%", pane: Pane(Property(content: [
                               (kind: Text(" ")),
                           ], align: Right))
               ),
            ]
        ),
    },
    cava: (bar_symbols: ['▁', '▂', '▃', '▄', '▅', '▆', '▇', '█'], bar_width: 1, bar_spacing: 1, bg_color: None, bar_color: Gradient({
            0: "{{ lighter_background }}",
            50: "{{ foreground }}",
            100: "{{ foreground }}",
        })),
    lyrics:(timestamp: false, alignment: Center),
    border_symbol_sets: {
    "rounded_collapsed_top": (parent: Rounded, top_left: "├", top_right: "┤"),
    },
)