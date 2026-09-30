/**
 * @name DiscordEffects
 * @description Adds the ability to put effects on your discord.
 * @version 2.1.9
 * @author Deleox
 * @authorId 1156430974008184962
 * @source https://github.com/Deleox/BDPlugins/blob/main/DiscordEffects/DiscordEffects.plugin.js
 * @website https://deleoxhub.org/Web/bio?p
 * Original Shooting Star CodePen By Delroy Prithvi - https://codepen.io/delroyprithvi/pen/LYyJROR
 * First plugin and learning experience so expect bugs and potentially awful code TT-TT
*/

const config = {
    changelog: [
        {
            title: "Bugfixes",
            type: "fixed",
            items: [
                "Fixed spelling misteaks!! but serious, i don't know why the rain speed option had the note 'Rain opacity'...",
                "Fixed the speed option and added one to the snowflakes, they now work."
            ]
        },
        {
            title: "More BD Compliance",
            type: "added",
            items: [
                "Changed element creation to BdApi.DOM.CreateElement",
                "Fixed a bug where effects wouldn't show until you change the span amount"
            ]
        }
    ],
    settings: [
        {
            type: "dropdown",
            id: "effect",
            name: "Effect",
            note: "Select the effect to display",
            value: "shootingStars",
            options: [
                {label: "Shooting Stars", value: "shootingStars"},
                {label: "Snowflakes", value: "snowflakes"},
                {label: "Rain", value: "rain"}
            ]
        },
        {
            type: "slider",
            id: "spanCount",
            name: "Span Count",
            note: "Adjust the number of spans for animation - More spans = more lag",
            value: 10, // Default span count
            min: 0,
            max: 50,
            markers: [10, 20, 30, 40, 50]
         },
        {
            type: "category",
            id: "AdvancedCat",
            name: "Advanced",
            collapsible: true,
            shown: false,
            settings: [
                {   
                    type: "number",
                    id: "zindexamount",
                    name: "Set Z-Index",
                    note: "Allows modifying the z-index to reduce bugs with effects.",
                    value: 5,
                },
            ]
        },
        {
            type: "category",
            id: "ShootingStarCat",
            name: "ShootingStars Settings",
            collapsible: true,
            shown: false,
            settings: [
                {
                    type: "slider",
                    id: "angle",
                    name: "Star Angle",
                    note: "Adjust the angle of the stars - refrain from use on live",
                    value: 315, // Default angle
                    min: 0,
                    max: 360,
                    markers: [0, 90, 180, 270, 360]
                }
            ]
        },
        {
            type: "category",
            id: "SnowflakeCat",
            name: "Snowflake Settings",
            collapsible: true,
            shown: false,
            settings: [
                {
                    type: "color", 
                    id: "flakecolor", 
                    name: "Snow Colorpicker", 
                    note: "Colorpicker for changing the color of the Snow - Default #ffffff", 
                    value: "#ffffff", 
                    colors: null,
                    inline: true
                },
                {
                    type: "number",
                    id: "flakeopacity",
                    name: "Snow Opacity",
                    note: "Set the opacity for the Snow",
                    value: .5,
                    min: 0,
                    max: 1,
                    step: .1
                },
                {
                    type: "number",
                    id: "flakemaxspeed",
                    name: "Max Snowflake Speed",
                    note: "Sets the snowflake speed",
                    value: 15,
                    min: 0,
                    max: 50,
                    step: .5
                }
            ]
        },
        {
            type: "category",
            id: "RainCat",
            name: "Rain Settings",
            collapsible: true,
            shown: false,
            settings: [
                {
                    type: "color", 
                    id: "raincolor", 
                    name: "Rain Colorpicker", 
                    note: "Colorpicker for changing the color of the Rain - Default #ffffff", 
                    value: "#ffffff", 
                    colors: null,
                    inline: true
                },
                {
                    type: "number",
                    id: "rainopacity",
                    name: "Rain Opacity",
                    note: "Set the opacity for the rain",
                    value: .5,
                    min: 0,
                    max: 1,
                    step: .1
                },
                {
                    type: "number",
                    id: "rainmaxspeed",
                    name: "Max rain speed",
                    note: "Set the speed for the rain",
                    value: .5,
                    min: 0,
                    max: 100,
                    step: .25
                }
            ]
        }
    ]
};

module.exports = class DiscordEffects {
    constructor(meta) {
        this.meta = meta;
        this.api = new BdApi(this.meta.name);
        this.settings = this.api.Data.load("settings") || config.settings.reduce((acc, setting) => {
            acc[setting.id] = setting.value;
            return acc;
        }, {});
    }

    start() {
        const savedVersion = this.api.Data.load("version");
        if (savedVersion !== this.meta.version) {
            this.api.UI.showChangelogModal({
                title: this.meta.name,
                subtitle: this.meta.version,
                blurb: "Public Release of [Discord Effects](https://deleox.github.io/BDPlugins/DiscordEffects/DiscordEffects.plugin.js), [Bio](https://deleoxhub.org/Web/bio).",
                changes: config.changelog
            });
            this.api.Data.save("version", this.meta.version);
        }
        this.addSection();
        this.firstlaunch();
    }

    firstlaunch() {
        if (!this.api.Data.load('firstlaunch')) {
            this.api.Data.save("settings", {
                "effect": "shootingStars",
                "spanCount": "10"
            });
            this.api.Data.save("firstlaunch", "false");
        }
        this.updateSpans();
        this.spanCount += 1;
    }

    stop() {
        this.removeSection();
    }

    updateSpans() {
        this.removeSection();
        this.addSection();
    }

    addSection() {
        this.removeSection();
        const section = BdApi.DOM.createElement('div');
        section.id = 'DiscordEffects';
        section.style.position = 'fixed';
        section.style.top = '0';
        section.style.left = '0';
        section.style.width = '100%';
        section.style.height = '100vh';
        section.style.overflow = 'hidden';
        section.style.pointerEvents = 'none';
        section.style.zIndex = this.settings.zindexamount;

        for (let i = 0; i < this.settings.spanCount; i++) {
            const span = BdApi.DOM.createElement('span');
            span.style.position = 'absolute';
            if (this.settings.effect === 'snowflakes') {
                span.style.top = '-10px';
                span.style.width = '10px';
                span.style.height = '10px';
                span.style.background = this.settings.flakecolor || 'white';
                span.style.opacity = this.settings.flakeopacity;
                span.style.borderRadius = '50%';
                span.style.left = `${Math.random() * 100}%`;
                span.style.animationDelay = `${Math.random() * 5}s`;
                span.style.animationDuration = `${Math.random() * this.settings.flakemaxspeed}s`
                //span.style.animationDuration = `${5 + Math.random() * 5}s`;
                span.style.animationName = 'fall';
                span.style.animationIterationCount = 'infinite';
                span.style.animationTimingFunction = 'linear';
            } else if (this.settings.effect === 'rain') {
                span.style.top = '-10px';
                span.style.width = '2px';
                span.style.height = '20px';
                span.style.background = this.settings.raincolor || 'linear-gradient(to bottom, rgba(255, 255, 255, 1), rgba(255, 255, 255, 0.2))';
                span.style.opacity = this.settings.rainopacity;
                span.style.borderRadius = '20%';
                span.style.left = `${Math.random() * 100}%`;
                span.style.animationDelay = `${Math.random() * 1}s`;
                span.style.animationDuration = `${Math.random() * this.settings.rainmaxspeed}s`;
                span.style.animationName = 'fall';
                span.style.animationIterationCount = 'infinite';
                span.style.animationTimingFunction = 'linear';
            }
            section.appendChild(span);
        }

        
        BdApi.DOM.addStyle('DiscordEffectsStyle', this.getEffectStyles());
        

        const appMount = document.querySelector('#app-mount');
        if (appMount) {
            appMount.appendChild(section);
        } else {
            console.error("If you're seeing this, you either have bigger issues or I somehow broke everything, I'm sorry :c\r\n#app-mount element not found.");
        }
    }

    removeSection() {
        const section = document.querySelector('#DiscordEffects');
        if (section) {
            section.remove();
        }
        BdApi.DOM.removeStyle('DiscordEffectsStyle');
    }

    getEffectStyles() {
        const angle = this.settings.angle || 315;

        function generateSpanStyles(count, getStyles) {
            return Array.from({ length: count }, (_, i) => `
                #DiscordEffects span:nth-child(${i + 1}) {
                    ${getStyles(i)}
                }
            `).join('');
        }

        const shootingStarsStyles = (i) => {
            const leftPosition = Math.random() * 100;
            return `
                top: 0;
                right: ${80 * (i + 1)}px;
                left: ${leftPosition}%;
                animation-delay: ${0.2 * i}s;
                animation-duration: ${1 + 0.25 * ((i % 4) + 1)}s;
            `;
        };

        const snowflakesStyles = (i) => {
            const leftPosition = Math.random() * 100;
            return `
                left: ${leftPosition}%;
                animation-delay: ${Math.random() * 5}s;
                animation-duration: ${5 + Math.random() * 5}s;
            `;
        };

        const rainStyles = (i) => {
            const leftPosition = Math.random() * 100;
            return `
                left: ${leftPosition}%;
                animation-delay: ${Math.random() * 1}s;
                animation-duration: ${0.5 + Math.random() * 1}s;
                overflow: hidden;
            `;
        };

        function generateRandomKeyframes(count) {
            return Array.from({ length: count }, (_, i) => `
                @keyframes randomPosition${i} {
                    0% { left: ${Math.random() * 100}%; }
                    100% { left: ${Math.random() * 100}%; }
                }
            `).join('');
        }

        switch (this.settings.effect) {
            case 'shootingStars':
                return `
                    #DiscordEffects {
                        position: absolute;
                        top: 0;
                        left: 0;
                        width: 100%;
                        height: 100vh;
                        background-size: cover;
                        animation: animateBg 50s linear infinite;
                        z-index: ${this.settings.zindexamount};
                    }

                    @keyframes animateBg {
                        0%, 100% {
                            transform: scale(1);
                        }
                        50% {
                            transform: scale(1.2);
                        }
                    }

                    #DiscordEffects span {
                        position: absolute;
                        top: 50%;
                        left: 50%;
                        width: 4px;
                        height: 4px;
                        background: #fff;
                        border-radius: 50%;
                        box-shadow: 0 0 0 4px rgba(255, 255, 255, 0.1), 0 0 0 8px rgba(255, 255, 255, 0.1), 0 0 20px rgba(255, 255, 255, 0.1);
                        animation: animate 3s linear infinite;
                        transform-origin: top left;
                    }

                    #DiscordEffects span::before {
                        content: '';
                        position: absolute;
                        top: 50%;
                        transform: translateY(-50%);
                        width: 300px;
                        height: 1px;
                        background: linear-gradient(90deg, #fff, transparent);
                    }

                    @keyframes animate {
                        0% {
                            transform: rotate(${angle}deg) translateX(0);
                            opacity: 1;
                        }
                        70% {
                            opacity: 1;
                        }
                        100% {
                            transform: rotate(${angle}deg) translateX(-1000px);
                            opacity: 0;
                        }
                    }

                    ${generateSpanStyles(this.settings.spanCount, shootingStarsStyles)}
                    ${generateRandomKeyframes(this.settings.spanCount)}
                `;
            case 'snowflakes':
                return `
                    #DiscordEffects {
                        position: absolute;
                        top: 0;
                        left: 0;
                        width: 100%;
                        height: 100vh;
                        background-size: cover;
                        z-index: ${this.settings.zindexamount};
                    }

                    #DiscordEffects span {
                        position: absolute;
                        top: -10px;
                        width: 10px;
                        height: 10px;
                        background: ${this.settings.flakecolor || 'white'};
                        opacity: ${this.settings.flakeopacity || 0.8};
                        border-radius: 50%;
                        animation: fall 10s linear infinite;
                    }

                    @keyframes fall {
                        to {
                            transform: translateY(100vh);
                            opacity: 0;
                        }
                    }

                    ${generateSpanStyles(this.settings.spanCount, snowflakesStyles)}
                    ${generateRandomKeyframes(this.settings.spanCount)}
                `;
            case 'rain':
                return `
                    #DiscordEffects {
                        position: absolute;
                        top: 0;
                        left: 0;
                        width: 100%;
                        height: 100vh;
                        background-size: cover;
                        z-index: ${this.settings.zindexamount};
                    }

                    #DiscordEffects span {
                        position: absolute;
                        top: -10px;
                        width: 2px;
                        height: 20px;
                        background: ${this.settings.raincolor || 'linear-gradient(to bottom, rgba(255, 255, 255, 0.5), rgba(255, 255, 255, 0.1))'};
                        opacity: ${this.settings.rainopacity || 0.6};
                        border-radius: 20%;
                        animation: fall 1s linear infinite;
                        animation-name: randomPosition${Math.floor(Math.random() * this.settings.spanCount)};
                    }

                    @keyframes fall {
                        to {
                            transform: translateY(100vh);
                            opacity: 0;
                        }
                    }

                    ${generateSpanStyles(this.settings.spanCount, rainStyles)}
                    ${generateRandomKeyframes(this.settings.spanCount)}
                `;
            default:
                return '';
        }
    }

    getSettingsPanel() {
        return BdApi.UI.buildSettingsPanel({
            settings: config.settings.map(setting => {
                if (setting.type === "category" && setting.collapsible) {
                    return {
                        ...setting,
                        settings: setting.settings.map(subSetting => {
                            let subValue = this.settings[subSetting.id] !== undefined ? this.settings[subSetting.id] : subSetting.value;
                            return {
                                ...subSetting,
                                value: subValue,
                            };
                        })
                    };
                } else {
                    let settingValue = this.settings[setting.id] !== undefined ? this.settings[setting.id] : setting.value;
                    return {
                        ...setting,
                        value: settingValue,
                    };
                }
            }),
            onChange: (category, id, value) => {
                this.settings[id] = value;
                this.api.Data.save("settings", this.settings);
                if (id === 'spanCount' || id === 'zindexamount') {
                    this.updateSpans();
                } else {
                    this.updateEffect();
                }
            },
        });
    }

    updateEffect() {
        this.removeSection();
        this.addSection();
    }
};